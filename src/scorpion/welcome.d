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
		view.compile!("scorpion-welcome.index.dt", example);
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

@Controller
class TestController {
	
	@Auth
	@Get("privet")
	getAuth(Response response, Session session) {
		response.body_ = "Welcome to the club, " ~ session.authentication.username;
	}

	@Auth("test")
	@Get("privet2")
	getAuth2(Response response, Session session) {
		import std.string : join;
		response.body_ = "You have a permission (" ~ session.authentication.roles.join(", ") ~ ")";
	}

	@Get("auth")
	getAuthMe(Response response, Session session, @Param string username, @Param string[] roles) {
		session.login(response, new A(username, roles));
	}

	@AuthRedirect("/")
	@Get("redirect")
	getRedirect(Response response) {
		response.body_ = "HELLO";
	}

	class A : Authentication {

		private string _username;
		private string[] _roles;

		this(string username, string[] roles) {
			_username = username;
			_roles = roles;
		}

		override uint userId() {
			return 0;
		}

		override string username() {
			return _username;
		}

		override string[] roles() {
			return _roles;
		}

	}

}
