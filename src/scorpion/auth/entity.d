module scorpion.auth.entity;

import scorpion;

@Entity("users")
class User {

	@Id
	@AutoIncrement
	Long userId;

	@NotNull
	string username;

	@NotNull
	ubyte[] password;

}
