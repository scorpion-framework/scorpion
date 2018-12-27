module scorpion.controller;

import lighttp.util : Status;

struct Controller {

	string[] path;

	this(string[] path...) {
		this.path = path;
	}

}

enum Path;

struct Route {

	string method;
	string[] path;

}

Route Get(string[] path...) {
	return Route("GET", path);
}

Route Post(string[] path...) {
	return Route("POST", path);
}

Route Put(string[] path...) {
	return Route("PUT", path);
}

Route Delete(string[] path...) {
	return Route("DELETE", path);
}

struct Code {

	this(uint status) {
		this.status = status;
	}

	this(Status status) {
		this.status = status.code;
	}

	uint status;

}
