module app;

import std.conv : to;
import std.json;

import scorpion;
import scorpion.gem.crud;

@Entity("book")
class Book {
	
	@PrimaryKey
	@AutoIncrement
	Integer bookId;
	
	@NotNull
	String title;
	
	@NotNull
	String author;
	
	JSONValue[string] toJSON() {
		return [
			"bookId": JSONValue(bookId.value),
			"title": JSONValue(title),
			"author": JSONValue(author)
		];
	}

}

@Component
interface BookRepository : CrudRepository!Book {}

@Controller("books")
class BooksController {

	@Init
	BookRepository repository;

	@Get
	getBooks(Response response) {
		JSONValue[] ret;
		foreach(value ; repository.selectAll()) ret ~= JSONValue(value.toJSON());
		response.body_ = ret;
	}
	
	@Get("([0-9]{1,9})")
	getBook(Response response, @Path uint bookId) {
		if(auto book = repository.select(Integer(bookId))) {
			response.body_ = book.toJSON();
		} else {
			response.status = StatusCodes.notFound;
		}
	}
	
	@Post
	postBooks(Response response, @Body AddBook info) {
		Book book = new Book();
		book.title = info.title;
		book.author = info.author;
		repository.insert(book);
		response.status = StatusCodes.created;
		response.headers["Location"] = "/books/" ~ book.bookId.to!string;
		response.body_ = book.toJSON();
	}
	
	@Put
	putBooks(Response response, @Body UpdateBook info) {
		if(auto book = repository.select(Integer(info.id))) {
			if(info.title.length) book.title = info.title;
			if(info.author.length) book.author = info.author;
			repository.update(book);
			response.body_ = book.toJSON();
		} else {
			response.status = StatusCodes.notFound;
		}
	}
	
	@Delete("([0-9]{1,9})")
	deleteBook(Response response, @Path uint bookId) {
		repository.removeById(Integer(bookId));
	}

}

private struct AddBook {

	@NotEmpty
	string title;
	
	@NotEmpty
	string author;

}

private struct UpdateBook {

	@NotZero
	uint id;
	
	string title;
	
	string author;

}
