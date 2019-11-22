package parsihax;

import parsihax.*;
import parsihax.Parser.*;
using parsihax.Parser;

// ADT definition
enum JsonExpression {
  JsonNull;
  JsonTrue;
  JsonFalse;
  JsonNumber(v : Float);
  JsonString(v : String);
  JsonPair(k : JsonExpression, v : JsonExpression);
  JsonArray(v : Array<JsonExpression>);
  JsonObject(v : Array<JsonExpression>);
}

class JsonGrammar {
  // This is the main entry point of the parser: a full Json document.
  static var json = (function() {
    return whitespace.then([
      object,
      array,
      stringLiteral,
      numberLiteral,
      nullLiteral,
      trueLiteral,
      falseLiteral
    ].alt());
  }).lazy();

  // Use the Json standard's definition of whitespace rather than Parsihax's.
  static var whitespace = ~/\s*/m.regexp();

  // Json is pretty relaxed about whitespace, so let's make it easy to ignore
  // after most text.
  static function token(parser) {
    return skip(parser, whitespace);
  }

  // This gets reused for both array and object parsing.
  static function commaSep(parser) {
    return sepBy(parser, token(','.string()));
  }

  // The basic tokens in Json, with optional whitespace afterward.
  static var lbrace = token('{'.string());
  static var rbrace = token('}'.string());
  static var lbracket = token('['.string());
  static var rbracket = token(']'.string());
  static var comma = token(','.string());
  static var colon = token(':'.string());

  // `.result` is like `.map` but it takes a value instead of a function, and
  // `.always returns the same value.
  static var nullLiteral = token('null'.string()).result(JsonNull);
  static var trueLiteral = token('true'.string()).result(JsonTrue);
  static var falseLiteral = token('false'.string()).result(JsonFalse);

  // regexp based parsers should generally be named for better error reporting.
  static var stringLiteral =
    token(~/"((?:\\.|.)*?)"/.regexp(1))
    // Turn escaped characters into real ones (e.g. "\\n" becoems "\n").
    .map(function interpretEscapes(str) {
      var escapes = [
        'b' => '\\b',
        'f' => '\\f',
        'n' => '\\n',
        'r' => '\\r',
        't' => '\\t'
      ];

      return JsonString(~/\\(u[0-9a-fA-F]{4}|[^u])/.map(str, function(reg) {
        var escape = reg.matched(0);
        var type = escape.charAt(0);
        var hex = escape.substr(1);
        if (type == 'u') return String.fromCharCode(Std.parseInt(hex));
        if (escapes.exists(type)) return escapes[type];
        return type;
      }));
    }).as('string');

  static var numberLiteral =
    token(~/-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?/.regexp())
    .map(function(result) return JsonNumber(Std.parseFloat(result)))
    .as('number');

  // Array parsing is just ignoring brackets and commas and parsing as many nested
  // Json documents as possible. Notice that we're using the parser `json` we just
  // defined above. Arrays and objects in the Json grammar are recursive because
  // they can contain any other Json document within them.
  static var array = lbracket.then(commaSep(json)).skip(rbracket)
    .map(function(results) return JsonArray(results));

  // Object parsing is a little trickier because we have to collect all the key-
  // value pairs in order as length-2 arrays, then manually copy them into an
  // object.
  static var pair =
    [stringLiteral.skip(colon), json].seq()
    .map(function(results) return JsonPair(results[0], results[1]));

  static var object =
    lbrace.then(commaSep(pair)).skip(rbrace)
    .map(function(pairs) return JsonObject(pairs));

  public static function build() {
    return json.apply;
  }
}
