module scorpion.model;

import std.array : Appender;
import std.string : split;

import diet.html : compileHTMLDietFile;

import lighttp.util : Request;

import scorpion.lang : LanguageManager, Lang;

class Model {

	private Request _request;
	private Lang _lang;

	this(Request request, LanguageManager languageManager) {
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

	@property Request request() {
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
