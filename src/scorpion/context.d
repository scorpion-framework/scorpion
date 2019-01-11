module scorpion.context;

import lighttp : ServerRequest, ServerResponse;

import scorpion.config : Config;
import scorpion.session : SessionManager, Session;

/**
 * Represents the context of the application in the current thread.
 */
final class Context {

	private Config _config;

	private SessionManager _sessionManager;
	private Session _session;

	private ServerRequest _request;
	private ServerResponse _response;

	this(Config config) {
		_config = config;
		_sessionManager = new SessionManager(config.get("scorpion.session.cookie", "DSESSIONID"));
	}

	/**
	 * Updates the context using the data from the next request.
	 */
	void refresh(ServerRequest request, ServerResponse response) {
		_session = null;
		_request = request;
		_response = response;
	}

	/**
	 * Gets the server's configuration.
	 */
	@property Config config() {
		return _config;
	}

	/**
	 * Gets the current request.
	 */
	@property ServerRequest request() {
		return _request;
	}

	/**
	 * Gets the current response.
	 */
	@property ServerResponse response() {
		return _response;
	}

	/**
	 * Gets the current session, lazily initialized.
	 */
	@property Session session() {
		if(_session is null) _session = _sessionManager.get(request);
		return _session;
	}

}
