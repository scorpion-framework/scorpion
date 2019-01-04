module scorpion.profile;

/**
 * Annotation for profiles. One or more profiles can be
 * added to the same annotation.
 * Example:
 * ---
 * @Profile("dev")
 * @Profile("dev", "spider-dev")
 * ---
 */
struct Profile {

	public static string[] get(E...)(E args) {
		string[] ret;
		foreach(profile ; args) {
			ret ~= profile.profiles;
		}
		return ret;
	}
	
	string[] profiles;

	this(string[] profiles...) {
		this.profiles = profiles;
	}

}
