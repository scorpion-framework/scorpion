module scorpion.config;

import std.conv : to;
import std.file : exists, read, write;
import std.string : split, strip, indexOf;

private enum defaultConfiguration = import("default-configuration.properties");

struct Config {

	private string[] _profiles;
	private string[string] _values;

	public @property string[] profiles() {
		return _profiles;
	}

	public void addProfiles(string[] profiles) {
		_profiles ~= profiles;
	}

	public bool hasProfile(string profile) {
		foreach(p ; _profiles) {
			if(p == profile) return true;
		}
		return false;
	}

	public bool hasProfile(string[] profiles...) {
		foreach(profile ; profiles) {
			if(hasProfile(profile)) return true;
		}
		return false;
	}

	public T get(T)(string key, lazy T defaultValue) {
		auto ptr = key in _values;
		if(ptr) return to!T(*ptr);
		else return defaultValue;
	}

	public static Config load() {
		if(!exists("scorpion.properties")) write("scorpion.properties", defaultConfiguration);
		Config config;
		loadImpl(config, "scorpion");
		return config;
	}

	private static void loadImpl(ref Config config, string file) {
		file ~= ".properties";
		if(exists(file)) {
			auto values = parseProperties(cast(string)read(file));
			foreach(key, value; values) config._values[key] = value;
			auto profiles = "scorpion.profiles" in values;
			if(profiles) {
				foreach(profile ; split(*profiles, ",")) {
					profile = profile.strip;
					config._profiles ~= profile;
					loadImpl(config, profile);
				}
			}
		}
	}

}

string[string] parseProperties(string data) {
	string[string] ret;
	foreach(line ; split(data, "\n")) {
		immutable sep = line.indexOf("=");
		if(sep != -1) {
			immutable key = line[0..sep].strip;
			if(key.length) {
				ret[key] = line[sep+1..$].strip;
			}
		}
	}
	return ret;
}

auto Value(string key){ return ValueImpl!Object(key, null); }

auto Value(T)(string key, T defaultValue){ return ValueImpl!T(key, defaultValue); }

struct ValueImpl(T) {

	string key;

	T defaultValue;

}

enum Configuration;

interface LanguageConfiguration {

	string[string] loadLanguages();

}

interface ProfilesConfiguration {

	string[] defaultProfiles();

}
