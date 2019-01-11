module app;

import scorpion;

@Controller
class JavascriptToDController {

	@Get
	getIndex(Response response) {
		response.body_ = "<script src='/assets/scorpion.js'></script>";
	}

	@Callable
	void firstFunction() {}

}
