Scorpion
<img align="right" alt="Logo" width="100" src="https://i.imgur.com/A7ozW1W.png">
=======

[![DUB Package](https://img.shields.io/dub/v/scorpion.svg)](https://code.dlang.org/packages/scorpion)
[![Build Status](https://travis-ci.org/scorpion-framework/scorpion.svg?branch=master)](https://travis-ci.org/scorpion-framework/scorpion)
[![Chat](https://img.shields.io/badge/chat-on%20discord-7289da.svg)](https://discord.gg/b3YQ3J6)

Scorpion is a web framework written in D built on top of [lighttp](https://github.com/Kripth/lighttp) that allows you to create websites and other web applications in a very simple way.

## Getting started

To create a new Scorpion project you'll need a [D compiler](https://dlang.org/download.html) and [DUB](https://code.dlang.org/download) installed on your machine.

After creating a new project add `scorpion` as a dependency to your `dub.sdl` or `dub.json` and create a controller.

`dub.sdl`
```sdl
name "example"
dependency "scorpion" version="..."
```

`src/example/controller.d`
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

Also, note that scoprion-boot does not work with [single-file packages](https://dub.pm/advanced_usage.html).

## Learn the basics

- [Configuration](docs/configuration.md)
- [Controllers](docs/controller.md)

## In depth

- [Creating a CRUD RESTful web service](examples/crud)
