module scorpion.context;

import lighttp : ServerRequest, ServerResponse;

import scorpion.config : Config;
import scorpion.session : SessionManager, Session;

class Context {

	private Config _config;

	private SessionManager _sessionManager;
	private Session _session;

	private ServerRequest _request;
	private ServerResponse _response;

	this(Config config) {
		_config = config;
	}

	void refresh(ServerRequest request, ServerResponse response) {
		_session = null;
		_request = request;
		_response = response;
	}

	@property Config config() {
		return _config;
	}

	@property ServerRequest request() {
		return _request;
	}

	@property ServerResponse response() {
		return _response;
	}

	@property Session session() {
		if(_session is null) _session = _sessionManager.get(request);
		return _session;
	}

}
