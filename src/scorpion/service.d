module scorpion.service;

import std.conv : to;
import std.string : startsWith;
import std.traits : ReturnType, Parameters, ParameterIdentifierTuple, hasUDA, getUDAs;

import shark : Database;

import scorpion.entity : Entity, ExtendEntity;

enum Service;

interface Repository(T) {}

enum IgnoreCase;

struct Where { string clause; }

alias OrderBy = Database.Clause.Order.Field;

enum OrderByRandom;

struct Limit {

	string lower, upper;

	this(string lower, string upper) {
		this.lower = lower;
		this.upper = upper;
	}

	this(string upper) {
		this("0", upper);
	}

	this(size_t lower, size_t upper) {
		this(lower.to!string, upper.to!string);
	}

	this(size_t upper) {
		this(0, upper);
	}

}

class DatabaseRepository(T:Repository!R, R) : T if(is(T == interface) /*&& is(T : Repository!R, R)*/) {

	private alias E = ExtendEntity!(R, getUDAs!(R, Entity)[0].name);

	private Database _database;

	public this(Database database) {
		_database = database;
	}

	mixin(extendInterface!(T, R));

}

private string extendInterface(T, E)() {
	string ret = "";
	foreach(i, immutable member; __traits(allMembers, T)) {
		alias R = ReturnType!(__traits(getMember, T, member));
		ret ~= "override ReturnType!(__traits(getMember, T, `" ~ member ~ "`)) " ~ member ~ "(Parameters!(__traits(getMember, T, `" ~ member ~ "`)) args){";
		static if(hasUDA!(__traits(getMember, T, member), Where)) {
			ret ~= "auto where = Database.Clause.Where.prepare!(E, `" ~ getUDAs!(__traits(getMember, T, member), Where)[0].clause ~ "`).build(args);";
		} else {
			ret ~= "auto where = Database.Clause.Where.init;";
		}
		static if(hasUDA!(__traits(getMember, T, member), OrderByRandom)) {
			ret ~= "enum order = Database.Clause.Order.random;";
		} else static if(hasUDA!(__traits(getMember, T, member), OrderBy)) {
			ret ~= "enum order = Database.Clause.Order(";
			foreach(order ; getUDAs!(__traits(getMember, T, member), OrderBy)) {
				//TODO convert member name
				ret ~= "Database.Clause.Order.Field(`" ~ order.name ~ "`, Database.Clause.Order.Field." ~ (order._asc ? "asc" : "desc") ~ "),";
			}
			ret ~= ");";
		} else {
			ret ~= "enum order = Database.Clause.Order.init;";
		}
		static if(hasUDA!(__traits(getMember, T, member), Limit)) {
			immutable limit = getUDAs!(__traits(getMember, T, member), Limit)[0];
			ret ~= "auto limit = Database.Clause.Limit(" ~ convert(limit.lower) ~ "," ~ convert(limit.upper) ~ ");";
		} else {
			ret ~= "enum limit = Database.Clause.Limit.init;";
		}
		static if(member.startsWith("select")) {
			static if(is(R == E)) {
				ret ~= "return _database.selectOne!E(Database.Select(where, order, limit));";
			} else {
				ret ~= "R[] ret; foreach(entity ; _database.select!E(Database.Select(where, order, limit))){ ret ~= entity; } return ret;";
			}
		} else static if(member.startsWith("insert")) {
			static assert(is(R == void));
			ret ~= "_database.insert(new E(args[0]));";
		} else {
			static assert(0, "Cannot implement method " ~ member);
		}
		ret ~= "}";
	}
	return ret;
}

private string convert(string str) {
	if(str.length && str[0] == '$') return "args[" ~ str[1..$] ~ "]";
	else return str;
}
