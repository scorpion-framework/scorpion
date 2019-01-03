module scorpion.validation;

import std.conv : to, ConvException;
import std.experimental.logger : traceImpl = trace;
import std.regex : PhobosRegex = Regex, regex, matchFirst;
import std.string : split, indexOf;
import std.traits : isArray, Parameters;
import std.uri : decodeComponent, emailLength;

import asdf : serializeToJson, deserialize, DeserializationException;

import lighttp : ServerRequest, ServerResponse, StatusCodes;

/**
 * Creates a custom validator attribute.
 * Note that due to a linker bug `func` cannot be a lambda.
 * Example:
 * ---
 * // validates only if the value is equals to `test`, case insensitive
 * bool validateExp(string value) {
 *    import std.string : toLower;
 *    return value.toLower() == "test";
 * }
 * alias Test = CustomValidation!validateExp;
 * ...
 * struct Form {
 * 
 *    @Test
 *    string test;
 * 
 * }
 * ---
 */
struct CustomValidation(alias func) {

	enum validator = true;

	Parameters!func[1..$] args;

	string message;

	bool validate(T)(T value) {
		return func(value, args);
	}

}

/**
 * Validates a string only if its length is higher
 * than 0.
 */
alias NotEmpty = CustomValidation!(notEmptyValidator);

private bool notEmptyValidator(string value){ return value.length > 0; }

/**
 * Validates a string only if its length is shorter or equals
 * to the given value.
 * Example:
 * ---
 * @Min(10)
 * ---
 */
alias Min = CustomValidation!(minValidator);

private bool minValidator(string value, size_t min){ return value.length >= min; }

/**
 * Validates a string only if its length is longer or equals
 * to the given value.
 * Example:
 * ---
 * @Max(100)
 * ---
 */
alias Max = CustomValidation!(maxValidator);

private bool maxValidator(string value, size_t max){ return value.length <= max; }

/**
 * Validates a number only if it's not 0.
 */
alias NotZero = CustomValidation!(notZeroValidator);

private bool notZeroValidator(long value){ return value != 0; }

/**
 * Validates a string using a regular expression.
 * Example:
 * ---
 * @Regex(`[a-zA-Z0-9]*`)
 * ---
 */
alias Regex = CustomValidation!(regexValidator);

private PhobosRegex!char[string] _cached;

private bool regexValidator(string value, string r){
	auto rg = {
		auto cached = r in _cached;
		if(cached) return *cached;
		auto ret = regex(r);
		_cached[r] = ret;
		return ret;
	}();
	auto result = matchFirst(value, rg);
	return !result.empty && result.pre.length == 0 && result.post.length == 0;
}

/**
 * Validates an email address using std.uri.emailLength.
 */
alias Email = CustomValidation!(emailValidator);

private bool emailValidator(string value) { return emailLength(value) == value.length; }

/**
 * Indicates that the field is optional. This means that, if set to
 * its initial state or not set, no validation will be done.
 * Example:
 * ---
 * @Min(5)
 * @Optional
 * string text;
 * 
 * // ok
 * ""
 * 
 * // not ok (min is 5)
 * "test"
 * ---
 */
enum Optional;

class Validation {

	static struct Error {

		string field;
		string message;

	}

	Error[] errors;

	@property bool valid() pure nothrow @safe @nogc {
		return errors.length == 0;
	}

	void apply(ServerResponse response) {
		if(!valid) {
			response.status = StatusCodes.badRequest;
			response.body_ = serializeToJson(this);
		}
	}

}

T validateParam(T)(string param, ServerRequest request, ServerResponse response) {
	auto values = request.url.queryParams[param];
	static if(isArray!T) {
		T ret;
		foreach(value ; values) {
			try {
				ret ~= to!(typeof(T.init[0]))(value);
			} catch(ConvException) {
				response.status = StatusCodes.badRequest;
				return [];
			}
		}
		return ret;
	} else {
		if(values.length) {
			try {
				return to!T(values[0]);
			} catch(ConvException) {}
		}
		response.status = StatusCodes.badRequest;
		return T.init;
	}
}

enum ContentType {

	formUrlencoded,
	json,

}

T validateBody(T)(ServerRequest request, ServerResponse response, ref Validation validation) {
	T ret;
	static if(is(T == class)) ret = new T();
	auto contentType = {
		auto ptr = "content-type" in request.headers;
		if(ptr is null) return ContentType.formUrlencoded;
		else switch(*ptr) with(ContentType) {
			case "application/json": return json;
			default: return formUrlencoded;
		}
	}();
	if(contentType == ContentType.formUrlencoded) {
		foreach(keyValue ; split(request.body_, "&")) {
			immutable eq = keyValue.indexOf("=");
			if(eq > 0) {
				immutable key = keyValue[0..eq];
				foreach(immutable member ; __traits(allMembers, T)) {
					static if(__traits(compiles, mixin("ret." ~ member ~ "=typeof(ret." ~ member ~ ").init"))) {
						if(key == member) {
							immutable value = decodeComponent(keyValue[eq+1..$]);
							try {
								static if(isArray!(typeof(__traits(getMember, T, member)))) enum op = "~=";
								else enum op = "=";
								mixin("ret." ~ member ~ op ~ "to!(typeof(__traits(getMember, T, member)))(value);");
								continue;
							} catch(ConvException) {
								trace(request, "field ", member, " with value '", value, "' cannot be converted to ", typeof(__traits(getMember, T, member)).stringof);
								validation.errors ~= Validation.Error(key, "conversionError");
								return T.init;
							}
						}
					}
				}
			} else {
				trace(request, "malformatted x-www-form-urlencoded");
				validation.errors ~= Validation.Error("*", "format");
				return T.init;
			}
		}
	} else if(contentType == ContentType.json) {
		try ret = deserialize!T(request.body_);
		catch(DeserializationException) {
			trace(request, "invalid JSON");
			validation.errors ~= Validation.Error("*", "format");
			return T.init;
		}
	}
	foreach(immutable member ; __traits(allMembers, T)) {
		static if(__traits(compiles, mixin("ret." ~ member ~ "=T.init." ~ member))) {{
			Validation.Error[] errors;
			bool optional = false;
			foreach(attr ; __traits(getAttributes, __traits(getMember, T, member))) {
				static if(is(attr == Optional)) {
					optional = true;
				} else static if(is(typeof(attr.validator))) {
					static if(__traits(compiles, attr())) {
						if(!attr().validate(mixin("ret." ~ member))) {
							errors ~= Validation.Error(member, "");
						}
					} else {
						if(!attr.validate(mixin("ret." ~ member))) {
							errors ~= Validation.Error(member, attr.message);
						}
					}
				}
			}
			if(!optional || mixin("ret." ~ member) != typeof(mixin("ret." ~ member)).init) validation.errors ~= errors;
		}}
	}
	return ret;
}

private void trace(E...)(ServerRequest request, E args) {
	traceImpl(request.address, " ", request.method, " ", request.url.path, ": ", args);
}
