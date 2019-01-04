module scorpion.register;

import std.conv : to;
import std.exception : enforce;
import std.experimental.logger : info;
import std.regex : Regex;
import std.string : split, join;
import std.traits : hasUDA, getUDAs, isFunction, Parameters, ParameterIdentifierTuple;

import lighttp.router : Router, routeInfo;
import lighttp.util : StatusCodes, ServerRequest, ServerResponse;

import scorpion.component : Component, Init, Value;
import scorpion.config : Config, Configuration, LanguageConfiguration, ProfilesConfiguration;
import scorpion.controller : Controller, Route, Path, Param, Body;
import scorpion.entity : Entity, ExtendEntity;
import scorpion.lang : LanguageManager;
import scorpion.profile : Profile;
import scorpion.service : Service, DatabaseRepository;
import scorpion.session : Session;
import scorpion.validation : Validation, validateParam, validateBody;
import scorpion.view : View;

import shark : Database;

private LanguageManager languageManager;

private ProfilesConfiguration[] profilesConfigurations;

private EntityInfo[] entities;

private ComponentInfo[] components;

private ServiceInfo[] services;

private ControllerInfo[] controllers;

private class Info {
	
	string[] profiles;

	this(string[] profiles) {
		this.profiles = profiles;
	}

}

private interface EntityInfo {

	void init(Config config, Database database);

}

private class EntityInfoImpl(T) : Info, EntityInfo {

	this(string[] profiles) {
		super(profiles);
	}

	override void init(Config config, Database database) {
		if(profiles.length == 0 || config.hasProfile(profiles)) {
			enforce!Exception(database !is null, "A database connection is required");
			database.init!T();
		}
	}

}

private interface ComponentInfo {

	Object instance();

	Object newInstance(Database);

}

private class ComponentInfoImpl(T) : ComponentInfo {

	private T cached;

	static this() {
		cached = new T();
	}

	override Object instance() {
		return cached;
	}

	override Object newInstance(Database database) {
		T ret = new T();
		initComponent(ret, database);
		return ret;
	}

}

private interface ServiceInfo {

	Object instance(Database);

}

private class ServiceInfoImpl(T) : ServiceInfo {

	private T cached;

	override Object instance(Database database) {
		if(cached is null) cached = new T(database);
		return cached;
	}

}

private interface ControllerInfo {

	void init(Router router, Config config, Database);

}

private class ControllerInfoImpl(T) : Info, ControllerInfo {

	this(string[] profiles) {
		super(profiles);
	}

	override void init(Router router, Config config, Database database) {
		if(profiles.length == 0 || config.hasProfile(profiles)) {
			T controller = new T();
			static if(!__traits(compiles, getUDAs!(T, Controller)[0]())) auto controllerPath = getUDAs!(T, Controller)[0].path;
			foreach(immutable member ; __traits(allMembers, T)) {
				static if(__traits(getProtection, __traits(getMember, T, member)) == "public") {
					immutable full = "controller." ~ member;
					static if(isFunction!(__traits(getMember, T, member))) {
						foreach(immutable uda ; __traits(getAttributes, __traits(getMember, T, member))) {
							static if(is(typeof(uda) == Route) || is(typeof(uda()) == Route)) {
								static if(is(typeof(controllerPath))) auto path = controllerPath ~ uda.path;
								else auto path = uda.path;
								alias F = __traits(getMember, T, member);
								auto fun = mixin(generateFunction!F(member));
								info("Routing ", uda.method, " /", path.join("/"), " to ", T.stringof, ".", member);
								router.add(routeInfo(uda.method, path.join(`\/`)), fun);
							}
						}
					} else {
						static if(hasUDA!(__traits(getMember, T, member), Init)) {
							initComponent(mixin(full), database);
						}
						static if(hasUDA!(__traits(getMember, T, member), Value)) {
							mixin(full) = config.get(getUDAs!(__traits(getMember, T, member), Value)[0].key, mixin(full));
						}
					}
				}
			}
		}
	}

	private static string generateFunction(alias M)(string member) {
		string[] ret = ["ServerRequest request", "ServerResponse response"];
		string body1 = "response.status=StatusCodes.ok;Validation validation=new Validation();";
		string body2;
		string[Parameters!M.length] call;
		bool validation = false;
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
		return "delegate(" ~ ret.join(",") ~ "){" ~ body1 ~ body2 ~ "controller." ~ member ~ "(" ~ join(cast(string[])call, ",") ~ ");validation.apply(response);}";
	}

}

private void initComponent(T)(ref T value, Database database) {
	foreach(component ; components) {
		if(cast(T)component.instance) {
			value = cast(T)component.newInstance(database);
			return;
		}
	}
	foreach(service ; services) {
		if(cast(T)service.instance(database)) {
			value = cast(T)service.instance(database);
			return;
		}
	}
}

void init(Router router, Config config, Database database) {
	foreach(profilesConfiguration ; profilesConfigurations) {
		config.addProfiles(profilesConfiguration.defaultProfiles());
	}
	info("Active profiles: ", config.profiles.join(", "));
	foreach(entityInfo ; entities) {
		entityInfo.init(config, database);
	}
	foreach(controllerInfo ; controllers) {
		controllerInfo.init(router, config, database);
	}
}

void registerModule(alias module_)() {
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
				components ~= new ComponentInfoImpl!(T)();
			}
			static if(hasUDA!(T, Service)) {
				services ~= new ServiceInfoImpl!(DatabaseRepository!(T))();
			}
			static if(hasUDA!(T, Controller)) {
				controllers ~= new ControllerInfoImpl!(T)(Profile.get(getUDAs!(T, Profile)));
			}
		}
	}
}
