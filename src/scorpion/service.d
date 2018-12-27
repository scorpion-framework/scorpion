module scorpion.service;

enum Service;

interface Repository(T) {}

enum IgnoreCase;

auto extendInterface(T)() if(is(T == interface)) {
	mixin({

			foreach(immutable member ; __traits(allMembers, T)) {
				pragma(msg, member);
			}

		}());
}
