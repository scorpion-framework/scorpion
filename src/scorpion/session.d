module scorpion.session;

import std.uuid : UUID, randomUUID;

import lighttp : Request, Response;

private enum cookieName = "SCORPION_SESSION_ID";

private Session[UUID] _sessions;

class Session {

	public static Session get(Request request) {
		auto cookies = "cookies" in request.headers;

		return new Session();
	}

	private Authentication _authentication;

	public @property bool loggedIn() {
		return _authentication !is null;
	}

	public @property Authentication authentication() {
		return _authentication;
	}

	public void login(Response response, Authentication authentication) {
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

	public @property long userId();

	public @property string username();

	public @property string[] roles();

}

struct Auth {

	this(string[] roles...) {
		this.roles = roles;
	}

	string[] roles;

}
