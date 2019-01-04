# Controllers

A controller maps paths to methods.

A controller is a public class annotated with `@Controller` that contains public methods annotated with `@Route` (`@Get`, used in the example, is an alias for `@Route("GET")`).

### Forget the `/`s

`Controller` and `Route` (and its aliases) can optionally take as arguments a path, not separated by `/` but by argument.
If a path is added to `@Controller`, all the routes in the class will start with the controller's path.

```d
@Controller
class Controller {

	// will route to /example
	@Get("example")
	getExample() {}

}
```
```d
@Controller("controller")
class Controller {

	// will route to /controller
	@Get
	getIndex() {}
	
	// will route to /controller/example/example
	@Get("example", "example")
	getExample() {}

}
```

### Arguments

A route can optionally take as arguments one or more of the following classes:

- `Request`: contains informations about the client's request.
- `Response`: contains informations about the response, like headers and body.
- `Session`: informations about the client's session ([code documentation](https://github.com/scorpion-framework/scorpion/blob/master/src/scorpion/session.d)).
- `View`: utility that can be used to compile [diet](https://github.com/rejectedsoftware/diet-ng/blob/master/SPEC.md) files ([code documentation](https://github.com/scorpion-framework/scorpion/blob/master/src/scorpion/view.d)).
- Annotated parameters.

#### Annotated parameters

Annotated parameters are parameters with special annotations that are used to get the request's informations more easily.

##### Path

`@Path` is used to get the result of a [regular expression](https://en.wikipedia.org/wiki/Regular_expression)'s capture in the path. For each capture group in the path a parameter annotated with `@Path` must also be present in the method's parameters.
```d
@Get("user", "([a-zA-Z0-9_]+)")
getUser(Response response, @Path string username) {
	writeln(username);
}
```
In this case `/user/Kripth` will print `Kripth`, but `/user/mark-white` will result in a `not found` client error, because `mark-white` does not match the regular expression `[a-zA-Z0-9_]+`.

Paths don't have to be strings: they can be any type convertible from a string, like numbers or booleans.
It's the programmer's job to make sure the input will be convertible from a string to the required type with a proper regular expression.

##### Param

`@Param` is used to get the query parameters from the url.

Like `@Path` it can be of any type convertible from a string. In this case no errors will be throws if the input is not convertible but a `bad request` client error will be returned to the client and the route's method will not even be called.
```d
@Get("number")
getExample(Response response, @Param int number) {
	writeln("Your number: ", number);
}
```
In this case `/number/92384` will print `92384`, but `/number/55.5` will result in `bad request` client error, because `55.5` cannot be converted to `int`.

##### Body

`@Body` is used to get the content of the request's body.