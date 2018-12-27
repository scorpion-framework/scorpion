module scorpion.register;

import std.conv : to;
import std.regex : Regex;
import std.stdio : writeln;
import std.string : split, join;
import std.traits : hasUDA, getUDAs, isFunction, Parameters;

import lighttp.router : Router, routeInfo;
import lighttp.util : Request, Response;

import scorpion.component : Component, Init;
import scorpion.config : Config, ValueImpl, Configuration, LanguageConfiguration, ProfilesConfiguration;
import scorpion.controller : Controller, Path, Route, Get, Post, Put, Delete;
import scorpion.lang : LanguageManager;
import scorpion.model : Model;
import scorpion.profile : Profile;
import scorpion.service : Service;

private LanguageManager languageManager;

private ProfilesConfiguration[] profilesConfigurations;

private ComponentInfo[] components;

private ControllerInfo[] controllers;

private class Info {
	
	string[] profiles;

	this(string[] profiles) {
		this.profiles = profiles;
	}

}

private interface ComponentInfo {

	Object newInstance();

}

private class ComponentInfoImpl(T) : ComponentInfo {

	override Object newInstance() {
		return new T();
	}

}

private interface ControllerInfo {

	void init(Router router, Config config);

}

private class ControllerInfoImpl(T) : Info, ControllerInfo {

	this(string[] profiles) {
		super(profiles);
	}

	override void init(Router router, Config config) {
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
								void delegate(Request, Response) fun = mixin(generateFunction!(__traits(getMember, T, member))(member));
								writeln("Routing ", uda.method, " /", path.join("/"), " to ", T.stringof, ".", member);
								router.add(routeInfo(uda.method, path.join(`\/`)), fun);
							}
						}
					} else {
						static if(hasUDA!(__traits(getMember, T, member), Init)) {
							//TODO
						}
						static if(hasUDA!(__traits(getMember, T, member), ValueImpl)) {
							immutable value = getUDAs!(__traits(getMember, T, member), ValueImpl)[0];
							mixin(full) = config.get!(typeof(value.defaultValue))(value.key, value.defaultValue);
						}
					}
				}
			}
		}
	}

	private static string generateFunction(alias M)(string member) {
		string[] ret = ["Request request", "Response response"];
		string body_ = "";
		string[] call = [];
		/*static foreach(i, param; M.opCall) {
			static if(hasUDA!(param, Path)) {
				pragma(msg, param);
				ret ~= param.stringof ~ " _" ~ i.to!string;
			}
		}*/
		foreach(i, param; Parameters!M) {
			static if(is(param == Request)) call ~= "request";
			else static if(is(param == Response)) call ~= "response";
			else static if(is(param == Model)) {
				body_ ~= "Model model = new Model(request, languageManager);";
				call ~= "model";
			} else {
				call ~= "Parameters!(__traits(getMember, T, member))[" ~ i.to!string ~ "].init";
			}
		}
		return "(" ~ ret.join(",") ~ "){" ~ body_ ~ "controller." ~ member ~ "(" ~ call.join(",") ~ ");}";
	}

}

void init(Router router, Config config) {
	foreach(profilesConfiguration ; profilesConfigurations) {
		config.addProfiles(profilesConfiguration.defaultProfiles());
	}
	writeln("Active profiles: ", config.profiles.join(", "));
	foreach(controllerInfo ; controllers) {
		controllerInfo.init(router, config);
	}
}

void registerModule(string module_)() {
	mixin("static import " ~ module_ ~ ";");
	foreach(immutable member ; __traits(allMembers, mixin(module_))) {
		static if(__traits(getProtection, __traits(getMember, mixin(module_), member)) == "public") {
			immutable full = module_ ~ "." ~ member;
			static if(hasUDA!(mixin(full), Configuration)) {
				mixin("alias T = " ~ full ~ ";");
				T configuration = new T();
				static if(is(T : LanguageConfiguration)) {
					foreach(lang, data; configuration.loadFrom()) {
						languageManager.add(lang, data);
					}
				}
				static if(is(T : ProfilesConfiguration)) {
					profilesConfigurations ~= configuration;
				}
			}
			static if(hasUDA!(mixin(full), Component)) {
				components ~= new ComponentInfoImpl!(mixin(full))();
			}
			static if(hasUDA!(mixin(full), Service)) {
				//TODO
			}
			static if(hasUDA!(mixin(full), Controller)) {
				controllers ~= new ControllerInfoImpl!(mixin(full))(Profile.get(getUDAs!(mixin(full), Profile)));
			}
		}
	}
}
