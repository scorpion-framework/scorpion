Creating a [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) RESTful web service
===============================

The CRUD paradigm is common in constructing web applications because it provides a good framework for remainding developers how to construct usable models.

In this example we'll create a library where books are identified by an unique id, a title and an author.

This is how the book's entity will look like:
```d
@Entity("book")
class Book {

	@PrimaryKey
	@AutoIncrement
	Integer bookId;
	
	@NotNull
	String title;
	
	@NotNull
	String author;

}
```

To create the repository we can extend `CrudRepository`, which provides us with five basic method that can be used to create, read, update and delete an entity.
```d
@Component
interface BookRepository : CrudRepository!Book {}
```

The base URL for every request will be `/books`, path that we will add to the controller's attribute:
```d
@Controller("books")
class BooksController {}
```

The last thing we need before getting started is to have access to the repository in the controller.
We can do that by marking a public instance of `BookRepository` with `@Init`:
```d
@Init
BookRepository repository;
```

## Create

To create a new resource we use the `POST` method, putting in the body of the request the new data.

```http
POST /books HTTP/1.1
Content-Type: application/json
Content-Length: 79

{
	"title": "Creating a CRUD RESTful web service",
	"author": "Mark White"
}
```

The controller must be able to handle the received data using the `@Body` annotation and a custom object that will be validated by Scorpion's validator.

```d
@Post
postBooks(Response response, @Body CreateBook info) {}
```

In the validation object we'll insert the fields that we'll received from the `POST` request.
```d
struct CreateBook {

	string title;
	string author;

}
```
But that's not enough! The current object will be accepted by the validator even if the parameter `title` and `author` are not present in the request's body or are empty.
To force this parameter to be in the request some attributes are required: the `@NotEmpty` attribute tells the validator to return a `400 Bad Request` client error when the paremter does not exist or it is empty.
```d
struct CreateBook {

	@NotEmpty
	string title;
	
	@NotEmpty
	string author;

}
```

Now it's time for creating the body of the method: it will need to create a new resource with the given parameters, save it, and return the saved data to the client.

The first step is creating a new resource and assign the fields sent by the client.
```d
Book book = new Book();
book.title = info.title;
book.author = info.author;
```

The second step is saving the newly created resource. We'll use the `insert` method provided by `CrudRepository`, which will also update the book's id as we marked it with `@AutoIncrement`.
```d
repository.insert(book);
```

The last step is returning the saved data to the client using a `201 Created` status code and adding the URL for the new resource in the `Location` header field.
For this action we'll use the `toJSON` method we wrote at the beginning of the guide.
```d
response.status = StatusCodes.created;
response.headers["Location"] = "/books/" ~ book.bookId.to!string;
response.body = book.toJSON();
```
Note that setting the header `Content-Type` to `application/json` is not needed as it will be done automatically.

The response will look something like this:
```http
HTTP/1.1 201 Created
Content-Length: 90
Content-Type: application/json

{
	"id": 1,
	"title": "Creating a CRUD RESTful web service",
	"author": "Mark White"
}
```

## Read

To read resources we'll use the `GET` method.
Reading a resource should never update its informations, only retrieve it.
If you retrieve the same resource twice you should always get the same result (unless someone else has changed it during the requests).

The read operation is divided in two methods: one for retrieving a specific resource, and one to retrieving all of them.

We'll start with the method that retrieves all resources:
```http
GET /books HTTP/1.1
```

This method won't need to have any special paramter:
```d
@Get
getBooks(Response response) {}
```

In the body of the method we need to retrieve all resources from the database and convert them to JSON.
To select the resources we can use the method `selectAll` provided by `CrudRepository`, loop through the result and convert it to JSON.
```d
JSONValue[] result;
foreach(book ; repository.selectAll()) {
	result ~= book.toJSON();
}
response.body = result;
```

The response will look something like this, as we only have one book saved in the database:
```http
HTTP/1.1 200 OK
Content-Length: 101
Content-Type: application/json

[
	{
		"id": 1,
		"title": "Creating a CRUD RESTful web service",
		"author": "Mark White"
	}
]
```

The second method is used to retrieve a specific resource, using its id:
```http
GET /books/1 HTTP/1.1
```

The method will then need to accept the book's id in its path:
```d
@Get("([0-9]{1,9})")
getBook(Response response, @Path uint id) {}
```

In the body of the method we need to check whether the requested resource exists, return it if it does or give an error if it does not.
For retrieving the resource from the database we can use the method `select` provided by `CrudRepository`.
```d
if(auto book = repository.select(Integer(id))) {
	response.body = book.toJSON();
} else {
	response.status = StatusCodes.notFound;
}
```

A successful request's response will look like this:
```http
HTTP/1.1 200 OK
Content-Length: 90
Content-Type: application/json

{
	"id": 1,
	"title": "Creating a CRUD RESTful web service",
	"author": "Mark White"
}
```

But if we try to retrieve a resource that does not exist, for example a book with id 2, the method will return a client error.
```http
GET /books/2 HTTP/1.1
```
```http
HTTP/1.1 404 Not Found
```

## Update

To update resources we'll use the `PUT` method.
The `PUT` method, like `POST`, has a body that can be used to send the updated data.

```http
PUT /books HTTP/1.1
Content-Length: 55
Content-Type: application/json

{
	"id": 1,
	"title": "Just CRUD example's README"
}
```

Like we did in the [create](#create) paragraph we create an object that will function as a validator.
This time it will contain a new field (the `id`) and the `title` and the `author` will be optional.
```d
struct UpdateBook {

	@NotZero
	uint id;
	
	string title, author;

}
```
The `@NotZero` annotation prevents `id` from being absent or `0`.

The controller's method will be similar to the one used when creating a new resource, except this time we'll use another object for validation.
```d
@Put
putBooks(Response response, @Body UpdateBook info) {}
```

This method's body will be the most complex of the five methods written in this guide as it will have to do four actions: 
first it will need to select the book from the database and check whether it exists, update the informations if they have been given in the object marked
with `@Body`, save the updated informations in the database by calling the `update` method provided by `CrudRepository` and return the updated data in JSON format.

To get the requested resource from the database we can use the `select` method like we did in the [read](#read) paragraph and return a `404 Not Found` client error if the resource does not exist.
```d
if(auto book = repository.select(Integer(info.id))) {

} else {
	response.status = StatusCodes.notFound;
}
```

If the resource does exist we can update it, save it and write it to the response's body:
```d
if(info.title.length) book.title = info.title;
if(info.author.length) book.author = info.author;
repository.update(book);
response.body = book.toJSON();
```

A successful response will look like this:
```http
HTTP/1.1 200 OK
Content-Length: 81
Content-Type: application/json

{
	"id": 1,
	"title": "Just CRUD example's README",
	"author": "Mark White"
}
```

## Delete

The last CRUD operation is used to delete resources from their id through the http `DELETE` method.
The `DELETE`, like the `GET` method, does not have a body and the id of the resource must be given through the request's path, like it has been done in the [read](#read) paragraph.

```http
DELETE /books/1 HTTP/1.1
```

The controller's method will accept the id in its path:
```d
@Delete("([0-9]{1,9})")
deleteBook(Response response, @Path uint id) {}
```

The method's body will be only doing two operations: delete the resource by calling the `remove` method, provided by `CrudRepository`,
and return a status code of `204 No Content`.
```d
repository.remove(Integer(id));
response.status = StatusCodes.noContent;
```

A successful response will look like this:
```http
HTTP/1.1 204 No Content
Content-Length: 0
```

# Conclusions

In conclusion, we used five methods to create (`POST /books`), read (`GET /books` and `GET /books/:id`), update (`PUT /books`) and delete (`DELETE /books/:id`)
books from a database.

You can browse [src/app.d](src/app.d) to view the complete code that has been written in this example.
