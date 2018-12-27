module scorpion.starter;

import std.ascii : newline;
import std.file : exists, write;
import std.stdio : writeln;
import std.string : join;

import lighttp;

import scorpion.config : Config;
import scorpion.register : init;

void start(string[] args) {
	
	if(!exists(".gitignore")) write(".gitignore", join([".dub", ".scorpion", "*.selections.json", "*.dll", "*.exe", "*.lib", "*.a"], newline));
	
	Config config = Config.load();
	
	immutable ip = config.get!string("scorpion.ip", "0.0.0.0");
	immutable port = config.get!ushort("scorpion.port", 80);

	writeln("Starting server on ", ip, ":", port);
	
	Server server = new Server("Scorpion");
	init(server.router, config);
	server.host(ip, port);
	server.run();
	
}
