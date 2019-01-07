module app;

import std.conv : to;
static import std.datetime;

import scorpion;
import scorpion.gem.crud;

@Entity("paste")
class Paste {

	@PrimaryKey
	@AutoIncrement
	Integer pasteId;
	
	@NotNull
	@Length(64)
	String title;
	
	@NotNull
	Clob content;
	
	//@NotNull
	//DateTime created;

}

@Component
interface PasteRepository : CrudRepository!Paste {}

@Controller
class PastebinController {

	@Init
	PasteRepository repository;

	//TODO homepage
	
	@Get("paste", Paths.integer)
	getPaste(Response response, View view, @Path uint id) {
		if(auto paste = repository.select(Integer(id))) {
			view.render!("paste.dt", paste);
		} else {
			response.status = StatusCodes.notFound;
		}
	}
	
	@Get("new")
	getNew(View view) {
		view.render!"new.dt";
	}
	
	@Post("new")
	postCreate(Response response, @Body PasteInfo info) {
		Paste paste = new Paste();
		paste.title = info.title;
		paste.content = info.content;
		//paste.created = cast(std.datetime.DateTime)std.datetime.Clock.currTime();
		repository.insert(paste);
		response.redirect(StatusCodes.temporaryRedirect, "/paste/" ~ paste.pasteId.to!string);
	}

}

private struct PasteInfo {

	@NotEmpty
	string title;
	
	@NotEmpty
	string content;

}
