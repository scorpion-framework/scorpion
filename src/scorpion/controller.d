module scorpion.controller;

import lighttp.util : Status;

/**
 * Attribute for controllers.
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

/**
 * Attributes for routes.
 * Indicates the method used (case sensitive, usually uppercase),
 * whether the method can have a body and the path.
 * Example:
 * ---
 * @Route("GET", false, "hello", "world") // GET /hello/world
 * @Post // POST /
 * @Delete("resource", "([a-z]+)") // DELETE /resource/:name
 * ---
 */
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

/// ditto
Route Get(string[] path...) {
	return Route("GET", false, path);
}

/// ditto
Route Post(string[] path...) {
	return Route("POST", true, path);
}

/// ditto
Route Put(string[] path...) {
	return Route("PUT", true, path);
}

/// ditto
Route Patch(string[] path...) {
	return Route("PATCH", true, path);
}

/// ditto
Route Delete(string[] path...) {
	return Route("DELETE", true, path);
}

/**
 * Attribute that indicates that the paramater is from a path's
 * regex capture.
 * The number of parameters annotated with `@Path` should correspond
 * to the number of captures in the path.
 * The type of the parameter can be any type that can be converted
 * from a string: it's the programmer's duty to write a regular expression
 * that won't cause any conversion exception.
 * Example:
 * ---
 * @Get("([a-z]+)")
 * _(Response response, @Path string capture) {
 *    ...
 * }
 * ---
 */
enum Path;

/**
 * Attribute that indicates that the parameter is from a path's
 * query.
 * The parameter's type can be any type that can be converted from
 * a string. If the conversion fails a `bad request` client error
 * is returned to the client and the handler is not called.
 * Example:
 * ---
 * @Get("hello")
 * _(Response response, @Param string username) {
 *    response.body_ = "Your username: " ~ username;
 * }
 * ---
 */
struct Param { string param; }

/**
 * Attribute that indicates that the parameter is converted from
 * the request's body.
 * The parameter must be either a struct or a class that will be
 * insantiated by the validator and validated by it.
 * The method is not usually called when the validation fails, but
 * if the method also contains a `scorpion.validation.Validation`
 * object as paramter the method is called even when the object
 * was not successfully validated.
 * To learn more about the validation process and the attributes
 * that can be added to the object's members to validate see the
 * `scorpion.validation` module's documentation.
 * Example:
 * ---
 * struct Message {
 * 
 *    string sender, message;
 * 
 * }
 * 
 * @Post("hello")
 * _(Response response, @Body Message message) {
 *    response.body_ = "Hello, " ~ message.sender ~ ", thanks for the message.";
 * }
 * ---
 */
enum Body;
