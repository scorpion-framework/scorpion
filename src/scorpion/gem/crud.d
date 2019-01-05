module scorpion.gem.crud;

import std.conv : to;
import std.string : join;
import std.traits : hasUDA;
import std.typetuple : TypeTuple;

import scorpion.repository;

import shark : PrimaryKey;

/**
 * Generates an interface with methods for creating,
 * reading, updating and deleting the given entity.
 * Example:
 * ---
 * @Entity("example")
 * class Example {
 * 
 *    @PrimaryKey
 *    Integer a;
 * 
 *    String b;
 * 
 * }
 * 
 * Example entity = new Example();
 * entity.b = "test";
 * repository.insert(entity);
 * assert(repository.select(entity.a).b == "test");
 * ---
 */
interface CrudRepository(T) : Repository!T if(Ids!T.length) {

	/**
	 * Selects and entity using the entity's primary key(s).
	 * Example:
	 * ---
	 * Example entity = repository.select(12);
	 * if(entity !is null) {
	 *    // do something
	 * }
	 * ---
	 */
	@Select
	@Where(generateWhere!T)
	T select(Ids!T args);

	/**
	 * Selects every entity in the table.
	 * Example:
	 * ---
	 * foreach(entity ; repository.selectAll()) {
	 *    // do something
	 * }
	 * ---
	 */
	@Select
	T[] selectAll();

	/**
	 * Inserts a new entity in the table.
	 * Example:
	 * ---
	 * Example entity = new Example();
	 * entity.b = "Hello!";
	 * repository.insert(entity);
	 * ---
	 */
	@Insert
	void insert(T entity);

	/**
	 * Updates an existing entity's fields.
	 * Example:
	 * ---
	 * if(auto entity = repository.select(1)) {
	 *    entity.b = "Updated";
	 *    repository.update(entity);
	 * }
	 * ---
	 */
	@Update
	void update(T entity);

	/**
	 * Removes an entity from the table.
	 * Example:
	 * ---
	 * Example entity = new Example();
	 * entity.a = 12;
	 * repository.remove(entity);
	 * ---
	 */
	@Remove
	void remove(T entity);

	/**
	 * Removes an entity from the table using its primary key(s).
	 * Example:
	 * ---
	 * repository.removeById(55);
	 * ---
	 */
	@Remove
	@Where(generateWhere!T)
	void removeById(Ids!T args);

}

private template Ids(T) {

	mixin(idsImpl!T);

}

private string idsImpl(T)() {
	string[] ret;
	foreach(immutable member ; __traits(allMembers, T)) {
		static if(hasUDA!(__traits(getMember, T, member), PrimaryKey)) {
			ret ~= "typeof(__traits(getMember, T, \"" ~ member ~ "\"))";
		}
	}
	return "alias Ids=TypeTuple!(" ~ ret.join(",") ~ ");";
}

private string generateWhere(T)() {
	size_t counter = 0;
	string[] ret;
	foreach(immutable member ; __traits(allMembers, T)) {
		static if(hasUDA!(__traits(getMember, T, member), PrimaryKey)) {
			ret ~= member ~ "=$" ~ to!string(counter++);
		}
	}
	return ret.join(" and ");
}
