module scorpion.view;

import std.array : Appender;
import std.string : split;

import diet.html : compileHTMLDietFile;

import lighttp.util : ServerRequest, ServerResponse;

import scorpion.lang : LanguageManager, Lang;

struct View {

	private ServerRequest _request;
	private ServerResponse _response;
	private Lang _lang;

	this(ServerRequest request, ServerResponse response, LanguageManager languageManager) {
		_request = request;
		_response = response;
		_lang = languageManager.get(languageManager.defaultLanguage);
		auto ptr = "accept-language" in request.headers;
		if(ptr) {
			foreach(language ; split(*ptr, ",")) {
				if(language.length >= 2 && languageManager.has(language[0..2])) {
					_lang = languageManager.get(language[0..2]);
					break;
				}
			}
		}
	}

	@property ServerRequest request() {
		return _request;
	}

	@property ServerResponse response() {
		return _response;
	}

	@property Lang lang() {
		return _lang;
	}

}

deprecated("use render instead") alias compile = render;

void render(string file, E...)(View view) {
	view.response.body_ = renderImpl!(file, E)(view);
}

string renderImpl(string file, E...)(View view) {
	Appender!string ret;
	ServerRequest request = view.request;
	Lang lang = view.lang;
	compileHTMLDietFile!(file, request, lang, E)(ret);
	return ret.data;
}
