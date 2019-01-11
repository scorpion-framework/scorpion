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
	
	@Value("scorpion.example")
	string example = "Welcome to Scorpion!";
	
	@Get
	getIndex(Response response, View view) {
		view.render!("scorpion-welcome.index.dt", example);
	}
	
}

@Controller("assets")
class ScorpionAssetsController {

	@Get("scorpion.svg")
	Resource logo;

	@Get("scorpion.js")
	Resource scorpionJs;
	
	this() {
		logo = new CachedResource("image/svg+xml", import("scorpion.logo.svg"));
		scorpionJs = new CachedResource("text/javascript", import("scorpion.js"));
	}
	
}
