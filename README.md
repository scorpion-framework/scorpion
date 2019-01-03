Scorpion
<img align="right" alt="Logo" width="100" src="https://i.imgur.com/A7ozW1W.png">
=======

[![DUB Package](https://img.shields.io/dub/v/scorpion.svg)](https://code.dlang.org/packages/scorpion)
[![Build Status](https://travis-ci.org/scorpion-framework/scorpion.svg?branch=master)](https://travis-ci.org/scorpion-framework/scorpion)

A web framework written in D.

=======

dub.sdl
```sdl
name "example"
dependency "scorpion" version="~>0.1"
dependency "scorpion-bootstrap" version="~>4.1.3"
```

views/index.dt
```
doctype html
html
	head
		title Welcome to Scorpion
	body
		p Welcome to Scorpion
```

src/controller.d
```d
module controller;

import scorpion;

@Controller
class ExampleController {

	@Get
	@Get("index.html")
	getIndex(Response response, Model model) {
		response.body = model.compile!"index.dt"();
	}

}
```