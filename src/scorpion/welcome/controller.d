module scorpion.welcome.controller;

import scorpion;

@Profile("scorpion-welcome")
@Controller
class ScorpionWelcomeController {

	@Value("scorpion.example", "Welcome to Scorpion!")
	string example;
	
	@Get
	getIndex(Response response, Model model) {
		response.headers["Content-Type"] = "text/html";
		response.body_ = model.compile!"scorpion-welcome.index.dt"(["example": example]);
	}

	/*@Get("number", "([0-9]*)")
	getNumber(Response response, @Path string number) {
		response.body_ = number;
	}*/

}

@Profile("scorpion-welcome")
@Controller("assets")
class ScorpionAssetsController {

	private Resource logo;

	this() {
		logo = new CachedResource("image/svg+xml", import("scorpion-logo.svg"));
	}

	@Get("logo.svg")
	getLogo(Request request, Response response) {
		logo.apply(request, response);
	}

}
