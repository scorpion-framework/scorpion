module scorpion.session;

import std.string : split, indexOf, strip;
import std.uuid : UUID, randomUUID, parseUUID, UUIDParsingException;

import lighttp : ServerRequest, ServerResponse;

private enum cookieName = "__scorpion_ssid";

private Session[UUID] _sessions;

class Session {

	public static Session get(ServerRequest request) {
		auto cookies = "cookie" in request.headers;
		if(cookies) {
			foreach(cookie ; split(*cookies, ";")) {
				immutable eq = cookie.indexOf("=");
				if(eq > 0) {
					immutable name = cookie[0..eq].strip;
					if(name == cookieName) {
						try {
							auto ret = parseUUID(cookie[eq+1..$].strip) in _sessions;
							if(ret is null) break;
							return *ret;
						} catch(UUIDParsingException) {
							break;
						}
					}
				}
			}
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
		response.headers["Set-Cookie"] = cookieName ~ "=" ~ uuid.toString() ~ "; Path=/";
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

}
