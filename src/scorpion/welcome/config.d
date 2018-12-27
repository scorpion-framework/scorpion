module scorpion.welcome.config;

import scorpion;

@Profile("scorpion-welcome")
@Configuration
class ScorpionWelcomeConfiguration : LanguageConfiguration {

	override string[string] loadFrom() {
		return [
			"en": import("scorpion-welcome.en.lang"),
			"it": import("scorpion-welcome.it.lang")
		];
	}

}
