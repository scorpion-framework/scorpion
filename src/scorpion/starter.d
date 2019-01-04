module scorpion.starter;

import std.ascii : newline;
import std.experimental.logger : sharedLog, LogLevel, info;
import std.file : exists, write;
import std.string : join;

import lighttp;

import scorpion.config : Config;
import scorpion.register : init;

import shark : Database, MysqlDatabase, PostgresqlDatabase;

void start(string[] args) {
	
	if(!exists(".gitignore")) write(".gitignore", join([".dub", ".scorpion", "*.selections.json", "*.dll", "*.exe", "*.lib", "*.a"], newline));
	
	Config config = Config.load();
	
	sharedLog.logLevel = {
		switch(config.get("scorpion.log", "info")) {
			case "all": return LogLevel.all;
			case "trace": return LogLevel.trace;
			case "info": return LogLevel.info;
			case "warning": return LogLevel.warning;
			case "error": return LogLevel.error;
			case "critical": return LogLevel.critical;
			case "fatal": return LogLevel.fatal;
			case "off": return LogLevel.off;
			default: throw new Exception("Invalid value for scorpion.log");
		}
	}();
	
	immutable ip = config.get!string("scorpion.ip", "0.0.0.0");
	immutable port = config.get!ushort("scorpion.port", 80);

	info("Starting server on ", ip, ":", port);

	Database database;
	immutable type = config.get("scorpion.database.driver", string.init);
	if(type !is null) {
		database = getDatabase(config, type);
		database.connect(config.get("scorpion.database.name", string.init), config.get("scorpion.database.user", "root"), config.get("scorpion.database.password", ""));
	}

	ServerOptions options;
	options.name = "Scorpion/~master";
	options.max = config.get("scorpion.upload.max", 2 ^^ 24); // 16 MB
	
	Server server = new Server(options);
	init(server.router, config, database);
	server.host(ip, port);
	server.run();
	
}

private Database getDatabase(Config config, string type) {
	switch(type) {
		case "mysql": return new MysqlDatabase(config.get("scorpion.database.host", "localhost"), config.get("scorpion.database.port", ushort(3306)));
		case "postgresql": return new PostgresqlDatabase(config.get("scorpion.database.host", "localhost"), config.get("scorpion.database.port", ushort(5432)));
		default: throw new Exception("Cannot create a database of type '" ~ type ~ "'");
	}
}
