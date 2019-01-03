module scorpion.welcome;

import scorpion;

@Profile("scorpion-welcome")
@Configuration
class ScorpionWelcomeConfiguration : LanguageConfiguration {
	
	override string[string] loadLanguages() {
		return [
			"en": import("scorpion-welcome.en.lang"),
			"it": import("scorpion-welcome.it.lang")
		];
	}
	
}

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
	
	@Get("number", "([0-9]*)")
	getNumber(Response response, @Path string number) {
		response.body_ = number;
	}
	
}

@Controller("assets")
class ScorpionAssetsController {
	
	private Resource logo;
	
	this() {
		logo = new CachedResource("image/svg+xml", import("scorpion.logo.svg"));
	}
	
	@Get("scorpion.svg")
	getLogo(Request request, Response response) {
		logo.apply(request, response);
	}
	
}
