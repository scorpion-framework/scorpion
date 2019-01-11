module scorpion.session;

import std.algorithm : canFind;
import std.string : split, indexOf, strip;
import std.uuid : UUID, randomUUID, parseUUID, UUIDParsingException;

import lighttp : ServerRequest, ServerResponse, StatusCodes, Cookie;

import scorpion.context : Context;

final class SessionManager {

	public immutable string cookieName;

	private Session[UUID] _sessions;

	public this(string cookieName) {
		this.cookieName = cookieName;
	}

	public void add(Session session, UUID uuid) {
		_sessions[uuid] = session;
	}

	public Session get(ServerRequest request) {
		if(auto cookie = cookieName in request.cookies) {
			try {
				if(auto ret = parseUUID(idup(*cookie)) in _sessions) return *ret;
			} catch(UUIDParsingException) {}
		}
		return new Session(this);
	}

}

final class Session {

	private SessionManager _sessionManager;

	private Authentication _authentication;

	public this(SessionManager sessionManager) {
		_sessionManager = sessionManager;
	}

	public @property bool loggedIn() {
		return _authentication !is null;
	}

	public @property Authentication authentication() {
		return _authentication;
	}

	public void login(ServerResponse response, Authentication authentication) {
		UUID uuid = randomUUID();
		Cookie cookie = Cookie(_sessionManager.cookieName, uuid.toString());
		cookie.maxAge = 3600; // 1 hour
		cookie.path = "/";
		cookie.httpOnly = true;
		response.add(cookie);
		_sessionManager.add(this, uuid);
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

	bool test(Context context) {
		Session session = context.session;
		if(session.loggedIn) {
			if(roles.length == 0) return true;
			else foreach(role ; roles) {
				if(session.authentication.roles.canFind(role)) return true;
			}
		}
		context.response.status = StatusCodes.unauthorized;
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

	bool test(Context context) {
		if(!_auth.test(context)) {
			context.response.redirect(StatusCodes.temporaryRedirect, location);
			return false;
		} else {
			return true;
		}
	}

}
