module scorpion.auth.service;

import scorpion;
import scorpion.auth.entity : User;

@Profile("scorpion-auth")
@Service
interface ScorpionAuthService : Repository!User {

	User getByUsername(@IgnoreCase string username);

	bool existsByUsername(@IgnoreCase string username);

	void save(User user);

}
