module scorpion.repository;

import std.algorithm : map;
import std.conv : to;
import std.string : startsWith, join;
import std.traits : ReturnType, Parameters, ParameterIdentifierTuple, hasUDA, getUDAs;

import shark : Database, PrimaryKey;

import scorpion.entity : Entity, ExtendEntity;

/**
 * Base interface for repositories. Every repository that implements
 * this interface will be extended by scorpion and its methods implemented.
 * Every method in the interface must have either the attribute @Select,
 * @Insert, @Update or @Remove that indicates which action the repository
 * will perform using the database.
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
 *    Time c;
 * 
 * }
 * 
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Select
 *    Example[] selectAll();
 * 
 *    @Insert
 *    void insert(Example);
 * 
 *    @Update
 *    void update(Example);
 * 
 *    @Remove
 *    void remove(Example);
 * 
 * }
 * ---
 */
interface Repository(T) {}

/**
 * Indicates that one or more entities will be selected from
 * the database. The return type of a method marked with the
 * @Select atribute can be either T or T[], where T is the entity
 * specified in the repository's declaration.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Select
 *    T[] selectAll();
 * 
 *    @Select
 *    T selectOne(Integer id);
 * 
 * }
 * ---
 */
enum Select;

/**
 * Indicates that a newly created entity will be inserted in
 * the database. If the entity has one or more primary keys
 * their values will be updated.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Insert
 *    void insert(Example entity);
 * 
 * }
 * ---
 */
enum Insert;

/**
 * Indicates that an existing entity will be updated.
 * The updated fields can be specified with the `Fields`
 * attribute; if the attributes is not present all fields
 * except the primary keys will be updated.
 * If the entity does not have any primary key the `Where`
 * attribute must also be present.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Update
 *    void update(Example entity);
 * 
 * }
 * ---
 */
enum Update;

/**
 * Deletes one or more entities from the database.
 * If the entity does not have any primary key the
 * `Where` attribute must also be present.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Remove
 *    void remove(Example entity);
 * 
 * }
 * ---
 * The name of the attribute id `Remove` and not
 * `Delete` due to a conflict with the `Delete` HTTP
 * method name and the fact that `delete` is a reserved
 * keyword in D, thus methods could not be called simply
 * `delete`.
 */
enum Remove;

/**
 * Adds a `where` clause to the query. This attribute can be
 * used with query that select, update and remove entities.
 * It is possible to use method's arguments in the `where`
 * clause by adding the dollar sign plus the index (starting
 * from 0, obviously) of the variable.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Select
 *    @Where("b=$0")
 *    Example[] selectByB(string b);
 * 
 *    @Update
 *    @Where("b=$0 or b=$1")
 *    void update(string b0, string b1);
 * 
 * }
 * ---
 */
struct Where { string clause; }

/**
 * Specifies in which order the result of a select query
 * should be returned.
 * It is possible to add one or more `OrderBy` attributes
 * to the same method with different field names.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @OrderBy("b")
 *    @OrderBy("a", OrderBy.desc)
 *    Example[] select();
 * 
 * }
 * ---
 */
alias OrderBy = Database.Clause.Order.Field;

/**
 * Specifies that the result of a select query should be
 * returned randomly ordered. This action is usually performed
 * directly from the database.
 * It's not possible to use any other order attribute associated
 * with this one.
 */
enum OrderByRandom;

/**
 * Limits the number of results returned by a select query.
 * It is possible, like in the `Where` attribute, to specify
 * a value using the arguments by adding the dollar sign and
 * the argument's index in the method.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Limit(5)
 *    Example[] select5();
 * 
 *    @Limit("$0", "$1")
 *    Example[] selectInRange(size_t lowerLimit, size_t upperLimit);
 * 
 * }
 * ---
 */
struct Limit {

	string lower, upper;

	this(L, U)(L lower, U upper) if(__traits(compiles, to!string(lower)) && __traits(compiles, to!string(upper))) {
		this.lower = lower.to!string;
		this.upper = upper.to!string;
	}

	this(U)(U upper) if(__traits(compiles, to!string(upper))) {
		this("0", upper);
	}

}

/**
 * Indicates which field(s) to update when updating an entity.
 * This is useful when having an entity with a field that holds
 * big data and and a small field that is updated frequently.
 * By adding the `Fields` attribute the big data is not sent to
 * the database and updated every time the small field is, saving
 * time.
 * Example:
 * ---
 * interface ExampleRepository : Repository!Example {
 * 
 *    @Update
 *    @Fields("b")
 *    void updateB(Example entity);
 * 
 *    @Update
 *    @Fields("c")
 *    void updateC(Example entity);
 * 
 * }
 * ---
 */
struct Fields {

	string[] fields;

	this(string[] fields...) {
		this.fields = fields;
	}

}

class DatabaseRepository(T:Repository!R, R) : T {

	private enum __table = getUDAs!(R, Entity)[0].name;
	private alias E = ExtendEntity!(R, __table);

	private Database _database;

	public this(Database database) {
		_database = database;
	}

	mixin(extendInterface!(T, R));

}

private string extendInterface(T, E)() {
	string ret = "";
	foreach(i, immutable member; __traits(allMembers, T)) {
		alias M = __traits(getMember, T, member);
		alias R = ReturnType!M;
		ret ~= "override ReturnType!(__traits(getMember, T, `" ~ member ~ "`)) " ~ member ~ "(Parameters!(__traits(getMember, T, `" ~ member ~ "`)) args){";
		static if(hasUDA!(M, Where)) {
			enum where = true;
			ret ~= "auto where = Database.Clause.Where.prepare!(E, `" ~ getUDAs!(M, Where)[0].clause ~ "`).build(args);";
		} else {
			enum where = false;
			ret ~= "enum where = Database.Clause.Where.init;";
		}
		static if(hasUDA!(M, OrderByRandom)) {
			ret ~= "enum order = Database.Clause.Order.random;";
		} else static if(hasUDA!(M, OrderBy)) {
			ret ~= "enum order = Database.Clause.Order(";
			foreach(order ; getUDAs!(M, OrderBy)) {
				//TODO convert member name
				ret ~= "Database.Clause.Order.Field(`" ~ order.name ~ "`, Database.Clause.Order.Field." ~ (order._asc ? "asc" : "desc") ~ "),";
			}
			ret ~= ");";
		} else {
			ret ~= "enum order = Database.Clause.Order.init;";
		}
		static if(hasUDA!(M, Limit)) {
			immutable limit = getUDAs!(__traits(getMember, T, member), Limit)[0];
			ret ~= "auto limit = Database.Clause.Limit(" ~ convert(limit.lower) ~ "," ~ convert(limit.upper) ~ ");";
		} else {
			ret ~= "enum limit = Database.Clause.Limit.init;";
		}
		static if(hasUDA!(M, Select)) {
			static if(is(R == E)) {
				ret ~= "return _database.selectOne!E(Database.Select(where, order, limit));";
			} else {
				ret ~= "R[] ret; foreach(entity ; _database.select!E(Database.Select(where, order, limit))){ ret ~= entity; } return ret;";
			}
		} else static if(hasUDA!(M, Insert)) {
			static assert(is(R == void));
			ret ~= "_database.insert(new E(args[0]));";
		} else static if(hasUDA!(M, Update)) {
			static if(hasUDA!(M, Fields)) enum fields = getUDAs!(M, Fields).fields;
			else enum fields = members!E;
			static if(where) {
				ret ~= "_database.update!([" ~ fields.map!(str => '"' ~ str ~ '"').join(",") ~ "])(new E(args[0]), where);";
			} else {
				ret ~= "_database.update!([" ~ fields.map!(str => '"' ~ str ~ '"').join(",") ~ "])(new E(args[0]));";
			}
		} else static if(hasUDA!(M, Remove)) {
			static if(Parameters!M.length == 1 && is(Parameters!M[0] == E)) {
				ret ~= "_database.del(new E(args[0]));";
			} else {
				ret ~= "_database.del(__table, where);";
			}
		} else {
			static assert(0, "Cannot implement method " ~ member ~ " because it's missing either @Select, @Insert, @Update or @Remove");
		}
		ret ~= "}";
	}
	return ret;
}

private string convert(string str) {
	if(str.length && str[0] == '$') return "args[" ~ str[1..$] ~ "]";
	else return str;
}

// copied from shark.database.getEntityMembers
private string[] members(T)() {
	string[] ret;
	foreach(immutable member ; __traits(allMembers, T)) {
		static if(!is(typeof(__traits(getMember, T, member)) == function) && __traits(compiles, mixin("new T()." ~ member ~ "=T." ~ member ~ ".init")) && !hasUDA!(__traits(getMember, T, member), PrimaryKey)) {
			ret ~= member;
		}
	}
	return ret;
}
