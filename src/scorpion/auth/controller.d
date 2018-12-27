module scorpion.auth.controller;

import scorpion;
import scorpion.auth.entity : User;
import scorpion.auth.service : ScorpionAuthService;
import scorpion.auth.util : PasswordEncoder;

@Profile("scorpion-auth")
@Controller
class ScorpionAuthController {

	@Init
	ScorpionAuthService authService;

	@Init
	PasswordEncoder passwordEncoder;

	@Value("scorpion.auth.login.success-redirect", "/")
	string loginSuccessRedirect;

	@Value("scorpion.auth.login.failure-redirect", "/login?failed")
	string loginFailedRedirect;

	@Value("scorpion.auth.logout.success-redirect", "/login?logout")
	string logoutSuccessRedirect;

	@Get("login")
	getLogin(Response response, Model model) {
		response.body_ = model.compile!"scorpion-auth.login.dt"();
	}

	@Post("login")
	postLogin(Response response, Session session, @Body LoginInfo info) {
		User user = authService.getByUsername(info.username);
		if(user.password == passwordEncoder.encode(info.password)) {
			session.login(response, new UsernamePasswordAuthentication(user.userId, user.username));
			response.redirect(loginSuccessRedirect);
		} else {
			response.redirect(loginFailedRedirect);
		}
	}

	@Get("register")
	getRegister(Response response, Model model) {
		response.body_ = model.compile!"scorpion-auth.register.dt"();
	}

	@Post("register")
	postRegister(Response response, @Body RegisterInfo info) {
		if(!authService.existsByUsername(info.username)) {
			User user = new User();
			user.username = info.username;
			user.password = passwordEncoder.encode(info.password);
			authService.save(user);
		} else {
			response.status = StatusCodes.badRequest;
		}
	}

	@Auth
	@Get("logout")
	getLogout(Session session, Response response) {
		session.logout();
		response.redirect(StatusCodes.temporaryRedirect, logoutSuccessRedirect);
	}

	static struct LoginInfo {

		@NotEmpty
		string username;

		@NotEmpty
		string password;

	}

	static struct RegisterInfo {

		@NotEmpty
		string username;

		@NotEmpty
		string password;

	}

}

private class UsernamePasswordAuthentication : Authentication {

	private long _userId;
	private string _username;

	public this(long userId, string username) {
		_userId = userId;
		_username = username;
	}

	public override @property long userId() {
		return _userId;
	}

	public override @property string username() {
		return _username;
	}

	public override @property string[] roles() {
		return [];
	}

}
