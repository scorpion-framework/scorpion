module scorpion.bootstrap;

import std.conv : to;
import std.exception : enforce;
import std.experimental.logger : sharedLog, LogLevel, info;
import std.regex : Regex;
import std.string : split, join;
import std.traits : hasUDA, getUDAs, isFunction, Parameters, ParameterIdentifierTuple;

import lighttp.resource : Resource;
import lighttp.router : Router, routeInfo;
import lighttp.server : ServerOptions, Server;
import lighttp.util : StatusCodes, ServerRequest, ServerResponse;

import scorpion.component : Component, Init, Value;
import scorpion.config : Config, Configuration, LanguageConfiguration, ProfilesConfiguration;
import scorpion.context : Context;
import scorpion.controller : Controller, Route, Path, Param, Body;
import scorpion.entity : Entity, ExtendEntity;
import scorpion.lang : LanguageManager;
import scorpion.profile : Profile;
import scorpion.repository : Repository, DatabaseRepository;
import scorpion.session : Session;
import scorpion.validation : Validation, validateParam, validateBody;
import scorpion.view : View;

import shark : Database, MysqlDatabase, PostgresqlDatabase;

/**
 * Stores instructions on how to build controllers, components
 * and entities.
 * This object is only used internally by scorpion for
 * initialization and bootstrapping of the server.
 */
final class ScorpionServer {

	/**
	 * Instance of the language manager. During the bootstrapping
	 * of the server language files are given to the language manager
	 * which converts them in key-value pairs.
	 * The language manager is the only object in the register class
	 * that is used after the server initialization.
	 */
	private LanguageManager languageManager;

	/**
	 * Contains instances of the `ProfilesConfiguration` configuration.
	 */
	private ProfilesConfiguration[] profilesConfigurations;

	/**
	 * Contains instructions on how to build entities.
	 */
	private EntityInfo[] entities;

	/**
	 * Contains informations about components and instructions on how
	 * to build a new one.
	 */
	private ComponentInfo[] components;

	/**
	 * Contains informations about services and instructions on how 
	 * to build a new one.
	 */
	private ServiceInfo[] services;

	/**
	 * Contains informations about controllers and a function to initialize
	 * routes.
	 */
	private ControllerInfo[] controllers;
	
	/**
	 * Scans a module for controllers, components and entities and
	 * adds the instructions for initialization in the register.
	 */
	public void registerModule(alias module_)() {
		foreach(immutable member ; __traits(allMembers, module_)) {
			static if(__traits(getProtection, __traits(getMember, module_, member)) == "public") {
				alias T = __traits(getMember, module_, member);
				static if(hasUDA!(T, Configuration)) {
					T configuration = new T();
					static if(is(T : LanguageConfiguration)) {
						foreach(lang, data; configuration.loadLanguages()) {
							languageManager.add(lang, data);
						}
					}
					static if(is(T : ProfilesConfiguration)) {
						profilesConfigurations ~= configuration;
					}
				}
				static if(hasUDA!(T, Entity)) {
					entities ~= new EntityInfoImpl!(ExtendEntity!(T, getUDAs!(T, Entity)[0].name))(Profile.get(getUDAs!(T, Profile)));
				}
				static if(hasUDA!(T, Component)) {
					//static if(is(T : Repository!R, R)) services ~= new ServiceInfoImpl!(DatabaseRepository!T)();
					static if(is(T : Repository!R, R)) components ~= new ComponentInfoImpl!(DatabaseRepository!T, true)(Profile.get(getUDAs!(T, Profile)));
					else components ~= new ComponentInfoImpl!(T, false)(Profile.get(getUDAs!(T, Profile)));
				}
				static if(hasUDA!(T, Controller)) {
					controllers ~= new ControllerInfoImpl!(T)(Profile.get(getUDAs!(T, Profile)));
				}
			}
		}
	}

	/**
	 * Starts the server by reading the configuration files and
	 * runs it. This function starts the event loop snd rever returns.
	 */
	public void run(string[] args) {

		Config config = Config.load();

		//TODO override configurations using args
		
		// sets the log level reading it from `scorpion.log` in the configuration files
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
		
		// initialize the database using values from `scorpion.database.*`
		Database database;
		immutable type = config.get("scorpion.database.driver", string.init);
		if(type !is null) {
			Database getDatabase() {
				switch(type) {
					case "mysql": return new MysqlDatabase(config.get("scorpion.database.host", "localhost"), config.get("scorpion.database.port", ushort(3306)));
					case "postgresql": return new PostgresqlDatabase(config.get("scorpion.database.host", "localhost"), config.get("scorpion.database.port", ushort(5432)));
					default: throw new Exception("Cannot create a database of type '" ~ type ~ "'");
				}
			}
			database = getDatabase();
			database.connect(config.get("scorpion.database.name", string.init), config.get("scorpion.database.user", "root"), config.get("scorpion.database.password", ""));
		}
		
		// creates the default options for the server
		ServerOptions options;
		options.name = "Scorpion/0.1";
		options.max = config.get("scorpion.upload.max", 2 ^^ 24); // 16 MB
		
		// creates the server, initializes it and starts the event loop
		Server server = new Server(options);
		init(server.router, config, database);
		server.host(ip, port);
		server.run();

	}

	/**
	 * Initializes entities and controllers.
	 */
	private void init(Router router, Config config, Database database) {
		Context context = new Context(config);
		foreach(profilesConfiguration ; profilesConfigurations) {
			config.addProfiles(profilesConfiguration.defaultProfiles());
		}
		info("Active profiles: ", config.profiles.join(", "));
		void filter(T)(ref T[] array) {
			T[] ret;
			foreach(element ; array) {
				auto info = cast(Info)element;
				if(info.profiles.length == 0 || config.hasProfile(info.profiles)) ret ~= element;
			}
			array = ret;
		}
		filter(entities);
		filter(components);
		filter(controllers);
		foreach(entityInfo ; entities) {
			entityInfo.init(context, database);
		}
		foreach(controllerInfo ; controllers) {
			controllerInfo.init(router, context, database);
		}
	}

	/**
	 * Tries to initialize a component and throws and exception
	 * on failure.
	 */
	private void initComponent(T)(ref T value, Database database) {
		foreach(component ; components) {
			T instance = cast(T)component.instance(database);
			if(instance !is null) {
				value = component.useCached ? instance : cast(T)component.newInstance(database);
				return;
			}
		}
		throw new Exception("Failed to initialize component of type " ~ T.stringof);
	}

	private class Info {
		
		string[] profiles;

		this(string[] profiles) {
			this.profiles = profiles;
		}

	}

	private interface EntityInfo {

		void init(Context context, Database database);

	}

	private class EntityInfoImpl(T) : Info, EntityInfo {

		this(string[] profiles) {
			super(profiles);
		}

		override void init(Context context, Database database) {
			enforce!Exception(database !is null, "A database connection is required");
			database.init!T();
		}

	}

	private interface ComponentInfo {

		@property bool useCached();

		Object instance(Database);

		Object newInstance(Database);

	}

	private class ComponentInfoImpl(T, bool repository) : Info, ComponentInfo {

		private T cached;
		
		this(string[] profiles) {
			super(profiles);
			static if(!repository) cached = new T();
		}

		override bool useCached() {
			return repository;
		}

		override Object instance(Database database) {
			static if(repository) if(cached is null) cached = new T(database);
			return cached;
		}

		override Object newInstance(Database database) {
			static if(repository) T ret = new T(database);
			else T ret = new T();
			initComponent(ret, database);
			return ret;
		}

	}

	private interface ControllerInfo {

		void init(Router router, Context context, Database);

	}

	private class ControllerInfoImpl(T) : Info, ControllerInfo {

		this(string[] profiles) {
			super(profiles);
		}

		override void init(Router router, Context context, Database database) {
			T controller = new T();
			static if(!__traits(compiles, getUDAs!(T, Controller)[0]())) enum controllerPath = getUDAs!(T, Controller)[0].path;
			foreach(immutable member ; __traits(allMembers, T)) {
				static if(__traits(getProtection, __traits(getMember, T, member)) == "public") {
					immutable full = "controller." ~ member;
					alias F = __traits(getMember, T, member);
					enum tests = {
						string[] ret;
						foreach(i, immutable uda; __traits(getAttributes, F)) {
							static if(is(typeof(__traits(getMember, uda, "test")) == function)) {
								static if(__traits(compiles, uda())) ret ~= "__traits(getAttributes, F)[" ~ i.to!string ~ "].init";
								else ret ~= "__traits(getAttributes, F)[" ~ i.to!string ~ "]";
							}
						}
						return ret;
					}();
					// weird bug on DMD 2.084: without the static foreach the compiler
					// says that variable `uda` cannot be read at compile time.
					static foreach(immutable uda ; __traits(getAttributes, F)) {
						static if(is(typeof(uda) == Route) || is(typeof(uda()) == Route)) {
							static if(is(typeof(controllerPath))) enum path = controllerPath ~ uda.path;
							else enum path = uda.path;
							enum regexPath = path.join(`\/`);
							static if(isFunction!F) {
								auto fun = mixin(generateFunction!F(T.stringof, member, regexPath, tests));
							} else {
								static assert(is(typeof(F) : Resource), "Member annotated with @Route must be callable or an instance of Resource");
								auto fun = delegate(ServerRequest request, ServerResponse response){
									context.refresh(request, response);
									static foreach(test ; tests) {
										if(!mixin(test).test(context)) return;
									}
									response.headers["X-Scorpion-Controller"] = T.stringof ~ "." ~ member;
									response.headers["X-Scorpion-Path"] = regexPath;
									mixin(full).apply(request, response);
								};
							}
							router.add(routeInfo(uda.method, uda.hasBody, regexPath), fun);
							info("Routing ", uda.method, " /", path.join("/"), " to ", T.stringof, ".", member, (isFunction!F ? "()" : ""));
						}
					}
					static if(hasUDA!(F, Init)) {
						initComponent(mixin(full), database);
					}
					static if(hasUDA!(F, Value)) {
						mixin(full) = context.config.get(getUDAs!(F, Value)[0].key, mixin(full));
					}
				}
			}
		}

	}

}

private string generateFunction(alias M)(string controller, string member, string path, string[] tests) {
	string[] ret = ["ServerRequest request", "ServerResponse response"];
	string body1 = "context.refresh(request,response);response.headers[`X-Scorpion-Controller`]=`" ~ controller ~ "." ~ member ~ "`;response.headers[`X-Scorpion-Path`]=`" ~ path ~ "`;";
	string body2, body3;
	string[Parameters!M.length] call;
	bool validation = false;
	foreach(test ; tests) {
		body1 ~= "if(!" ~ test ~ ".test(context)){return;}";
	}
	body1 ~= "response.status=StatusCodes.ok;Validation validation=new Validation();";
	foreach(i, param; Parameters!M) {
		static if(is(param == ServerRequest)) call[i] = "request";
		else static if(is(param == ServerResponse)) call[i] = "response";
		else static if(is(param == View)) {
			body2 ~= "View view=View(request,response,languageManager);";
			call[i] = "view";
		} else static if(is(param == Session)) {
			body2 ~= "Session session=Session.get(request);";
			call[i] = "session";
		} else static if(is(param == Validation)) {
			call[i] = "validation";
			validation = true;
		} else static if(is(typeof(M) Params == __parameters)) {
			immutable p = "Parameters!F[" ~ i.to!string ~ "] " ~ member ~ i.to!string;
			call[i] = member ~ i.to!string;
			foreach(attr ; __traits(getAttributes, Params[i..i+1])) {
				static if(is(attr == Path)) {
					ret ~= p;
				} else static if(is(attr == Param) || is(typeof(attr) == Param)) {
					static if(is(attr == Param)) enum name = ParameterIdentifierTuple!M[i];
					else enum name = attr.param;
					body1 ~= p ~ "=validateParam!(Parameters!F[" ~ i.to!string ~ "])(\"" ~ name ~ "\",request,response);";
					body1 ~= "if(response.status.code==400){return;}";
				} else static if(is(attr == Body)) {
					body1 ~= p ~ "=validateBody!(Parameters!F[" ~ i.to!string ~ "])(request,response,validation);";
				}
			}
		}
	}
	if(validation) body2 ~= "validation.apply(response);if(response.status.code==400){return;}";
	else body3 = "validation.apply(response);";
	return "delegate(" ~ ret.join(",") ~ "){" ~ body1 ~ body2 ~ "controller." ~ member ~ "(" ~ join(cast(string[])call, ",") ~ ");" ~ body3 ~ "}";
}

unittest {

	static import scorpion.welcome;

	ScorpionServer server = new ScorpionServer();
	server.registerModule!(scorpion.welcome);

}
