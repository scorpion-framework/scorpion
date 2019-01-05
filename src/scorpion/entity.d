module scorpion.entity;

static import shark.entity;

/**
 * Attribute that entities should be marked with.
 * The first and only required parameter indicates the
 * name of the table the entity belongs to.
 * Example:
 * ---
 * @Entity("scorpion_example")
 * class Example {
 * 
 *    ...
 * 
 * }
 * ---
 */
struct Entity {

	string name;

}

class ExtendEntity(T, string table) : T, shark.entity.Entity {

	override string tableName() {
		return table;
	}

	this() {}

	this(T entity) {
		foreach(immutable member ; __traits(allMembers, T)) {
			static if(__traits(compiles, mixin(member)=mixin("entity." ~ member))) {
				mixin(member) = mixin("entity." ~ member);
			}
		}
	}

}
