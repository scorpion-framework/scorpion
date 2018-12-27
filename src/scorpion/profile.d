module scorpion.profile;

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
