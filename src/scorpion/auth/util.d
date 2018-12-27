module scorpion.auth.util;

import std.digest.sha : sha256Of;

import scorpion;

@Profile("scorpion-auth")
@Component
class PasswordEncoder {

	ubyte[] encode(string password) {
		return sha256Of(password).dup;
	}

}
