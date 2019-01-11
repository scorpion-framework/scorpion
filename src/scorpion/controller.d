module scorpion.controller;

import lighttp.util : Status, ServerRequest, ServerResponse;

import scorpion.context : Context;

/**
 * Attribute for controllers to be used with classes that contain
 * routes.
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
 * @Post                                  // POST /
 * @Delete("resource", "([a-z]+)")        // DELETE /resource/:name
 * ---
 */
struct Route {

	/**
	 * Method accepted, conventionally uppercase.
	 */
	string method;

	/**
	 * Indicates whether the request can have a body. If set false
	 * the body, if present, is always ignored.
	 */
	bool hasBody;

	/**
	 * Route's path. It is later glued used path separators by
	 * the router manager.
	 */
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
 * Callable functions are routes that can be called from javascipt
 * using scorpion's javscript file (served to `/assets/scorpion.js`),
 * calling the `scorpion.call` javscript function.
 * The javascipt function takes a arguments the name of the function,
 * an object with the function's parameter and a callback. Both the
 * object and the callbacks are optional.
 * Example:
 * ---
 * // D code
 * @Callable
 * uint randomInteger() {
 *    return uniform!uint();
 * }
 * 
 * // JS code
 * scorpion.call("randomInteger", {}, number => console.log(number));
 * ---
 * Example:
 * ---
 * // D code
 * @Callable
 * void startProcess(string name) {
 *    processFactory.start(name);
 * }
 * 
 * // JS code
 * scorpion.call("startProcess", {name: "my_process"});
 * ---
 * The `Callable` attribute, like other routes, can also be used with
 * other custom attributes such as `Auth` and `AuthRedirect`.
 */
struct Callable {

	/**
	 * Optional name of the function. If not present it defaults
	 * to the function's name the `Callable` attribute is associated
	 * with.
	 */
	string functionName;

}

/**
 * Useful regular expressions for routing.
 * Note that every regular expression in this enum is enclosed
 * in a capturing group.
 */
enum Paths : string {

	/**
	 * Matches a number between 0 and 255.
	 */
	signedByte = `(1?[0-9]{1,2}|2[0-4][0-9]|25[0-5])`,

	/**
	 * Matches a number between 0 and 999,999,999.
	 */
	integer = `([0-9]{1,9})`,

	/**
	 * Matches a number between 1 and 31.
	 */
	day = `(3[01]|[12][0-9]|[1-9])`,

	/**
	 * Matches a number between 1 and 12.
	 */
	month = `([1-9]|1[0-2])`,

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
struct Param {

	/**
	 * Indicates the name of the parameter. If not present defaults
	 * to the identifier of the function's parameter that the `Param`
	 * attribute is associated to.
	 */
	string param;

}

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

/**
 * Attribute that marks a function as asynchronous. It means that the
 * response is not sent to the client when the method returns but when
 * the `send` function is called in the response.
 * This attribute should be used when the route's method permorms an
 * asynchrous action such as a client http call or using the database.
 * Example:
 * ---
 * @Async
 * @Get
 * getAsync(Response response) {
 *    new Client().connect("example.com").get("/").success((ClientResponse cresponse){
 *       response.body = cresponse.body;
 *       response.send();
 *    });
 * }
 * ---
 */
struct Async {

	bool test(Context context) {
		context.response.ready = false;
		return true;
	}

}
