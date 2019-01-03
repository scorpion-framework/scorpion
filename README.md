Scorpion
<img align="right" alt="Logo" width="100" src="https://i.imgur.com/A7ozW1W.png">
=======

[![DUB Package](https://img.shields.io/dub/v/scorpion.svg)](https://code.dlang.org/packages/scorpion)
[![Build Status](https://travis-ci.org/scorpion-framework/scorpion.svg?branch=master)](https://travis-ci.org/scorpion-framework/scorpion)
[![Chat](https://img.shields.io/badge/chat-on%20discord-7289da.svg)](https://discord.gg/b3YQ3J6)

Scorpion is a web framework written in D built on top of [lighttp](https://github.com/Kripth/lighttp) that allows you to create websites and other web applications in a very simple way.

## Getting started

To create a new Scorpion project you'll need a [D compiler](https://dlang.org/download.html) and [DUB](https://code.dlang.org/download) installed on your machine.

To get started simply add `scoprion` as a dependency to your `dub.sdl` or `dub.json` and create controller.

dub.sdl
```sdl
name "example"
dependency "scorpion" version="..."
```

src/example/controller.d
```d
module example.controller;

import scorpion;

@Controller
class ExampleController {

	@Get
	getIndex(Response response) {
		response.body = "Hello, world!";
	}

}
```

You can add [scorpion-boot](https://scorpion-boot.dub.pm) as a dependency to your application to automatically generate an executable file instead of a library.

Note that scorpion-boot will use the `.scorpion` folder to store build scipts, you may want to add `/.scoprion` to your `.gitignore`.

### Controllers

A controllers maps paths to methods.

A controller is a public class annotated with `@Controller` that contains public methods annotated with `@Route` (`@Get`, used in the example, is an alias for `@Route("GET")`).

#### Forget the `/`s

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

#### Arguments

A route can optionally take as arguments one or more of the following classes:

- `Request`: contains informations about the client's request.
- `Response`: contains informations about the response, like headers and body.
- `Session`: informations about the client's session.
- `Model`: model that can be used to compile diet files.
- Annotated parameters.

#### Annotated parameters

Annotated parameters are parameters with special annotations that are used to get the request's informations more easily.

##### Path

`@Path` is used to get the result of a regular expression's capture in the path. For each capture group in the path a parameter annotated with `@Path` must also be present in the method's parameters.
```d
@Get("user", "([a-zA-Z0-9_]+)")
getUser(Response response, @Path string username) {
	writeln(username);
}
```
`/user/Kripth` will print `Kripth`, but `/user/mark-white` will result in a `not found` client error, because `mark-white` does not match the regular expression `[a-zA-Z0-9_]+`.

Paths don't have to be strings: they can be any type convertible from a string, like numbers or booleans.
It's the programmer's job to make sure the input will be convertible from a string to the required type with a proper regular expression.

#### Param

`@Param` is used to get the query parameters from the url.

Like `@Path` it can be of any type convertible from a string. In this case no errors will be throws if the input is not convertible but a `bad request` client error will be returned to the client and the route's method will not even be called.
```d
@Get("number")
getExample(Response response, @Param int number) {
	writeln("Your number: ", number);
}
```
`/number/92384` will print `92384`, but `/number/55.5` will result in `bad request` client error, because `55.5` cannot be converted to `int`.

##### Body

`@Body` is used to get the content of the request's body.
