module scorpion.register;

import std.conv : to;
import std.exception : enforce;
import std.experimental.logger : info;
import std.regex : Regex;
import std.string : split, join;
import std.traits : hasUDA, getUDAs, isFunction, Parameters, ParameterIdentifierTuple;

import lighttp.resource : Resource;
import lighttp.router : Router, routeInfo;
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

	void init(Context context, Database database);

}

private class EntityInfoImpl(T) : Info, EntityInfo {

	this(string[] profiles) {
		super(profiles);
	}

	override void init(Context context, Database database) {
		if(profiles.length == 0 || context.config.hasProfile(profiles)) {
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

	void init(Router router, Context context, Database);

}

private class ControllerInfoImpl(T) : Info, ControllerInfo {

	this(string[] profiles) {
		super(profiles);
	}

	override void init(Router router, Context context, Database database) {
		if(profiles.length == 0 || context.config.hasProfile(profiles)) {
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
								static assert(is(typeof(F) : Resource), "Member annotated with @Route must be an instance of Resource");
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
	Context context = new Context(config);
	foreach(profilesConfiguration ; profilesConfigurations) {
		config.addProfiles(profilesConfiguration.defaultProfiles());
	}
	info("Active profiles: ", config.profiles.join(", "));
	foreach(entityInfo ; entities) {
		entityInfo.init(context, database);
	}
	foreach(controllerInfo ; controllers) {
		controllerInfo.init(router, context, database);
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
				static if(is(T : Repository!R, R)) services ~= new ServiceInfoImpl!(DatabaseRepository!T)();
				else components ~= new ComponentInfoImpl!(T)();
			}
			static if(hasUDA!(T, Controller)) {
				controllers ~= new ControllerInfoImpl!(T)(Profile.get(getUDAs!(T, Profile)));
			}
		}
	}
}
