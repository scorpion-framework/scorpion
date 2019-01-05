module scorpion.session;

import std.algorithm : canFind;
import std.string : split, indexOf, strip;
import std.uuid : UUID, randomUUID, parseUUID, UUIDParsingException;

import lighttp : ServerRequest, ServerResponse, StatusCodes, Cookie;

private enum cookieName = "__scorpion_session_id";

private Session[UUID] _sessions;

class Session {

	public static Session get(ServerRequest request) {
		if(auto cookie = cookieName in request.cookies) {
			try {
				if(auto ret = parseUUID(idup(*cookie)) in _sessions) return *ret;
			} catch(UUIDParsingException) {}
		}
		return new Session();
	}

	private Authentication _authentication;

	public @property bool loggedIn() {
		return _authentication !is null;
	}

	public @property Authentication authentication() {
		return _authentication;
	}

	public void login(ServerResponse response, Authentication authentication) {
		UUID uuid = randomUUID();
		Cookie cookie = Cookie(cookieName, uuid.toString());
		cookie.maxAge = 3600; // 1 hour
		cookie.path = "/";
		cookie.httpOnly = true;
		response.add(cookie);
		_sessions[uuid] = this;
		_authentication = authentication;
	}

	public void logout() {
		_authentication = null;
	}

}

interface Authentication {

	public @property uint userId();

	public @property string username();

	public @property string[] roles();

}

struct Auth {

	this(string[] roles...) {
		this.roles = roles;
	}

	string[] roles;

	bool test(ServerRequest request, ServerResponse response) {
		Session session = Session.get(request);
		if(session.loggedIn) {
			if(roles.length == 0) return true;
			else foreach(role ; roles) {
				if(session.authentication.roles.canFind(role)) return true;
			}
		}
		response.status = StatusCodes.unauthorized;
		return false;
	}

}

struct AuthRedirect {

	private string location;
	private Auth _auth;

	this(string location, string[] roles...) {
		this.location = location;
		_auth = Auth(roles);
	}

	bool test(ServerRequest request, ServerResponse response) {
		if(!_auth.test(request, response)) {
			response.redirect(StatusCodes.temporaryRedirect, location);
			return false;
		} else {
			return true;
		}
	}

}
