module scorpion.model;

import std.array : Appender;
import std.string : split;

import diet.html : compileHTMLDietFile;

import lighttp.util : ServerRequest;

import scorpion.lang : LanguageManager, Lang;

class Model {

	private ServerRequest _request;
	private Lang _lang;

	this(ServerRequest request, LanguageManager languageManager) {
		_request = request;
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

	@property Lang lang() {
		return _lang;
	}

	string compile(string template_)(string[string] model=(string[string]).init) {
		Appender!string ret;
		compileHTMLDietFile!(template_, request, lang, model)(ret);
		return ret.data;
	}

}
