package test;

import parsihax.Parsihax.*;
using parsihax.Parsihax;

// ADT definition
enum JSONExpression {
  JSONNull;
  JSONTrue;
  JSONFalse;
  JSONNumber(v : Int);
  JSONString(v : String);
  JSONPair(k : JSONExpression, v : JSONExpression);
  JSONArray(v : Array<JSONExpression>);
  JSONObject(v : Array<JSONExpression>);
}

class JSONTest {
  public static function parse(text : String) {
    // Create reference to JSON first so we will be able to recurse
    var json = ref();

    // Use the JSON standard's definition of whitespace rather than Parsihax's.
    var whitespace = ~/\s*/m.regexp();

    // JSON is pretty relaxed about whitespace, so let's make it easy to ignore
    // after most text.
    function token(p) {
      return skip(p, whitespace);
    }

    // This gets reused for both array and object parsing.
    function commaSep(parser) {
      return sepBy(parser, token(','.string()));
    }

    // The basic tokens in JSON, with optional whitespace afterward.
    var lbrace = token('{'.string());
    var rbrace = token('}'.string());
    var lbracket = token('['.string());
    var rbracket = token(']'.string());
    var comma = token(','.string());
    var colon = token(':'.string());

    // `.result` is like `.map` but it takes a value instead of a function, and
    // `.always returns the same value.
    var nullLiteral = token('null'.string()).result(JSONNull);
    var trueLiteral = token('true'.string()).result(JSONTrue);
    var falseLiteral = token('false'.string()).result(JSONFalse);

    // Regexp based parsers should generally be named for better error reporting.
    var stringLiteral = token(~/"((?:\\.|.)*?)"/.regexp(1))
        // Turn escaped characters into real ones (e.g. "\\n" becoems "\n").
        .map(function interpretEscapes(str) {
          var escapes = [
            'b' => '\\b',
            'f' => '\\f',
            'n' => '\\n',
            'r' => '\\r',
            't' => '\\t'
          ];

          return JSONString(~/\\(u[0-9a-fA-F]{4}|[^u])/.map(str, function(reg) {
            var escape = reg.matched(0);
            var type = escape.charAt(0);
            var hex = escape.substr(1);
            if (type == 'u') return String.fromCharCode(Std.parseInt(hex));
            if (escapes.exists(type)) return escapes[type];
            return type;
          }));
        })
        .desc('string');

    var numberLiteral = token(~/-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?/.regexp())
        .map(function(result) return JSONNumber(Std.parseInt(result)))
        .desc('number');

    // Array parsing is just ignoring brackets and commas and parsing as many nested
    // JSON documents as possible. Notice that we're using the parser `json` we just
    // defined above. Arrays and objects in the JSON grammar are recursive because
    // they can contain any other JSON document within them.
    var array = lbracket.then(commaSep(json)).skip(rbracket)
        .map(function(results) return JSONArray(results));

    // Object parsing is a little trickier because we have to collect all the key-
    // value pairs in order as length-2 arrays, then manually copy them into an
    // object.
    var pair = [stringLiteral.skip(colon), json].seq()
      .map(function(results) return JSONPair(results[0], results[1]));

    var object = lbrace.then(commaSep(pair)).skip(rbrace)
      .map(function(pairs) return JSONObject(pairs));

    // This is the main entry point of the parser: a full JSON document.
    json.set(function() {
      return whitespace.then([
        object,
        array,
        stringLiteral,
        numberLiteral,
        nullLiteral,
        trueLiteral,
        falseLiteral
      ].alt());
    }.lazy());

    return json.parse(text);
  }
}