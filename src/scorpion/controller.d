module scorpion.controller;

import lighttp.util : Status;

struct Controller {

	string[] path;

	this(string[] path...) {
		this.path = path;
	}

}

struct Route {

	string method;
	string[] path;

	this(string method, string[] path...) {
		this.method = method;
		this.path = path;
	}

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

Route Patch(string[] path...) {
	return Route("PATCH", path);
}

Route Delete(string[] path...) {
	return Route("DELETE", path);
}

enum Path;

struct Param { string param; }

enum Body;
