module scorpion.config;

import std.conv : to;
import std.file : exists, read, write;
import std.string : split, strip, indexOf;

private enum defaultConfiguration = import("default-configuration.properties");

/**
 * Stores the configuration key/values and the used profiles
 * from the configuration files.
 */
struct Config {

	private string[] _profiles;
	private string[string] _values;

	/**
	 * Gets the active profiles, read from the scorpion.profiles
	 * properties and from the `ProfilesConfiguration` configuration.
	 */
	public @property string[] profiles() {
		return _profiles;
	}

	public void addProfiles(string[] profiles) {
		_profiles ~= profiles;
	}

	/**
	 * Indicates whether a profile is active.
	 */
	public bool hasProfile(string profile) {
		foreach(p ; _profiles) {
			if(p == profile) return true;
		}
		return false;
	}

	/**
	 * Indicates whether at least one of the profiles in the
	 * given array is active.
	 */
	public bool hasProfile(string[] profiles...) {
		foreach(profile ; profiles) {
			if(hasProfile(profile)) return true;
		}
		return false;
	}

	/**
	 * Gets a configuration value from its key.
	 */
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

/**
 * Annotation for a configuration class. Does not take any argument.
 * A configuration class should extend one or more of the configuration
 * interfaces.
 * Example:
 * ---
 * @Configuration
 * class ExampleConfig : ProfilesConfig {
 * 
 *    override string[] defaultProfiles() {
 *       return ["example"];
 *    }
 * 
 * }
 * ---
 */
enum Configuration;

/**
 * Configuration for the language files.
 * Language files use the format `key=value`.
 */
interface LanguageConfiguration {

	/**
	 * Returns a map of the language files, alredy read.
	 * Example:
	 * ---
	 * override string[string] loadLanguages() {
	 *    return ["en": cast(string)read("res/lang/en.lang")];
	 * }
	 * ---
	 */
	string[string] loadLanguages();

}

/**
 * Configuration for default profiles.
 * This configuration adds the profiles in the configuration
 * files the ones returned by `defaultProfiles`;
 */
interface ProfilesConfiguration {

	/**
	 * Gets the default profiles.
	 */
	string[] defaultProfiles();

}
