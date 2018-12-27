/++ dub.sdl:
	name "scorpion-init"
	dependency "sdlang-d" version="~>0.10.4"
+/
module scorpioninit;

import std.algorithm : canFind;
import std.ascii : newline;
import std.file : exists, read, write, dirEntries, SpanMode;
import std.json;
import std.string;

import sdlang;

enum libs = ["diet-ng", "kiss", "lighttp", "my-ip", "xbuffer"];

void main(string[] args) {

	version(Windows) {
		import core.sys.windows.shlobj : SHGetFolderPath, CSIDL_LOCAL_APPDATA;
		import core.sys.windows.windef : MAX_PATH;
		import core.sys.windows.winerror : S_OK;
		import std.utf : toUTF8;
		wchar[] result = new wchar[MAX_PATH];
		assert(SHGetFolderPath(cast(void*)null, CSIDL_LOCAL_APPDATA, cast(void*)null, 0, result.ptr) == S_OK);
		immutable local = fromStringz((toUTF8(result)).ptr);
	} else {
		import std.process : executeShell;
		immutable local = executeShell("cd ~ && pwd").output.strip;
	}

	string name;
	
	if(exists("dub.json")) {
		JSONValue root = parseJSON(cast(string)read("dub.json"));
		name = root["name"].str;
	} else {
		Tag root = parseSource(cast(string)read("dub.sdl"));
		name = root.getTagValue!string("name");
	}
	
	string[] sources;
	
	void addSources(string path) {
		string[] search = ["source", "src"];
		//TODO read dub.json or dub.sdl and extract source paths
		foreach(s ; search) {
			if(exists(s)) sources ~= path ~ s;
		}
	}
	
	addSources("./");
	
	foreach(lname, value ; parseJSON(cast(string)read("dub.selections.json"))["versions"].object) {
		if(!libs.canFind(lname)) {
			if(value.type == JSON_TYPE.STRING) {
				addSources(local ~ "/dub/packages/" ~ lname ~ "-" ~ value.str ~ "/" ~ lname ~ "/");
			} else {
				addSources(value["path"].str ~ "/");
			}
		}
	}
	
	string[] modules;
	
	foreach(path ; sources) {
		foreach(string file ; dirEntries(path, SpanMode.breadth)) {
			if(file.endsWith(".d")) {
				auto data = cast(string)read(file);
				immutable module_ = data.indexOf("module "); //TODO may be in a comment
				if(module_ != -1) {
					data = data[module_..$];
					immutable semicolon = data.indexOf(";");
					if(semicolon != -1) {
						modules ~= "registerModule!\"" ~ data[6..semicolon].strip ~ "\"();";
					}
				}
			}
		}
	}
	
	auto data = [
		"/++ dub.sdl:",
		"name \"scorpion-starter\"",
		"targetName \"" ~ name ~ "\"",
		"targetPath \"exe\"",
		"dependency \"" ~ name ~ "\" path=\"..\"",
		"+/",
		"module scorpionstarter;",
		"import scorpion.register : registerModule;",
		"import scorpion.starter : start;",
		"void main(string[] args){"
	];
	data ~= modules;
	data ~= "start(args); }";
	write(".scorpion/starter.d", join(data, newline));

}
