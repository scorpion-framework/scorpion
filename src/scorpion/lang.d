module scorpion.lang;

import std.string : split, indexOf, strip;

struct LanguageManager {

	private Lang[string] languages;

	void add(string language, string data) {
		auto ptr = language in languages;
		if(ptr) {
			(*ptr).load(data);
		} else {
			Lang lang;
			lang.load(data);
			languages[language] = lang;
		}
	}

	bool has(string language) {
		return !!(language in languages);
	}

	Lang get(string language) {
		return languages[language];
	}

	@property string defaultLanguage() {
		return "en";
	}

}

struct Lang {

	string[string] values;

	void load(string data) {
		foreach(line ; data.split("\n")) {
			immutable sep = line.indexOf("=");
			if(sep != -1) {
				immutable key = line[0..sep].strip;
				if(key.length) {
					values[key] = line[sep+1..$].strip;
				}
			}
		}
	}

	alias values this;

}
