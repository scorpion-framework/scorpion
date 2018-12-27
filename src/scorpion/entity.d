module scorpion.entity;

struct Entity {

	string name;

}

enum Id;

enum NotNull;

enum AutoIncrement;

class Nullable(T) {

	public T value;

	alias value this;

}

alias Bool = Nullable!bool;

alias Byte = Nullable!byte;

alias Short = Nullable!short;

alias Integer = Nullable!int;

alias Long = Nullable!long;

string prepareQuery(T)() {



}
