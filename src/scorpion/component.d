module scorpion.component;

/**
 * Annotation for components.
 */
enum Component;

/**
 * Annotation for component's variables that should be
 * automatically initialized.
 */
enum Init;

/**
 * Annotations for values that should be initialized from a
 * configuration key. To be used in controllers and components.
 */
struct Value {
	
	string key;
	
}
