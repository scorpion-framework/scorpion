module scorpion.controller;

import lighttp.util : Status;

/**
 * Annotation for controllers.
 * Example:
 * ---
 * @Controller
 * @Controller("path")
 * @Controller("more", "complex", "path")
 * ---
 */
struct Controller {

	string[] path;

	this(string[] path...) {
		this.path = path;
	}

}

struct Route {

	string method;
	bool hasBody;
	string[] path;

	this(string method, bool hasBody, string[] path...) {
		this.method = method;
		this.hasBody = hasBody;
		this.path = path;
	}

}

Route Get(string[] path...) {
	return Route("GET", false, path);
}

Route Post(string[] path...) {
	return Route("POST", true, path);
}

Route Put(string[] path...) {
	return Route("PUT", true, path);
}

Route Patch(string[] path...) {
	return Route("PATCH", true, path);
}

Route Delete(string[] path...) {
	return Route("DELETE", true, path);
}

enum Path;

struct Param { string param; }

enum Body;
