module scorpion.entity;

static import shark.entity;

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
