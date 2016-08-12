package test;

import parsihax.Parser;
import parsihax.Parser.Ref;
import parsihax.Parser as P;

class JSON {
  public static function parse(text : String) {
    // Create reference to JSON first so we will be able to recurse
    var json : Ref<Dynamic> = P.ref();

    // Turn escaped characters into real ones (e.g. "\\n" becoems "\n").
    function interpretEscapes(str) {
      var escapes = [
        'b' => '\\b',
        'f' => '\\f',
        'n' => '\\n',
        'r' => '\\r',
        't' => '\\t'
      ];

      return ~/\\(u[0-9a-fA-F]{4}|[^u])/.map(str, function(reg) {
        var escape = reg.matched(0);
        var type = escape.charAt(0);
        var hex = escape.substr(1);
        if (type == 'u') return String.fromCharCode(Std.parseInt(hex));
        if (escapes.exists(type)) return escapes[type];
        return type;
      });
    }

    // Use the JSON standard's definition of whitespace rather than Parsihax's.
    var whitespace = P.regexp(~/\s*/m);

    // JSON is pretty relaxed about whitespace, so let's make it easy to ignore
    // after most text.
    function token(p) {
      return p.skip(whitespace);
    }

    // This gets reused for both array and object parsing.
    function commaSep(parser) {
      return P.sepBy(parser, token(P.string(',')));
    }

    // The basic tokens in JSON, with optional whitespace afterward.
    var lbrace = token(P.string('{'));
    var rbrace = token(P.string('}'));
    var lbracket = token(P.string('['));
    var rbracket = token(P.string(']'));
    var comma = token(P.string(','));
    var colon = token(P.string(':'));

    // `.result` is like `.map` but it takes a value instead of a function, and
    // `.always returns the same value.
    var nullLiteral : Parser<Dynamic> = token(P.string('null')).result(null);
    var trueLiteral : Parser<Dynamic> = token(P.string('true')).result(true);
    var falseLiteral : Parser<Dynamic> = token(P.string('false')).result(false);

    // Regexp based parsers should generally be named for better error reporting.
    var stringLiteral : Parser<Dynamic> =
      token(P.regexp(~/"((?:\\.|.)*?)"/, 1))
        .map(interpretEscapes)
        .desc('string');

    var numberLiteral : Parser<Dynamic> =
      token(P.regexp(~/-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?/))
        .map(function (result) { return Std.parseInt(result); })
        .desc('number');

    // Array parsing is just ignoring brackets and commas and parsing as many nested
    // JSON documents as possible. Notice that we're using the parser `json` we just
    // defined above. Arrays and objects in the JSON grammar are recursive because
    // they can contain any other JSON document within them.
    var array : Parser<Dynamic> = lbracket.then(commaSep(json)).skip(rbracket);

    // Object parsing is a little trickier because we have to collect all the key-
    // value pairs in order as length-2 arrays, then manually copy them into an
    // object.
    var pair : Parser<Dynamic> = P.seq([stringLiteral.skip(colon), json]);

    var object : Parser<Dynamic> =
      lbrace.then(commaSep(pair)).skip(rbrace).map(function(pairs) {
        var out = new Map<String, Dynamic>();
        var rPairs : Array<Dynamic> = pairs;

        for (pair in rPairs) {
          out[pair[0]] = pair[1];
        }

        return out;
      });
    

    // This is the main entry point of the parser: a full JSON document.
    json.set(P.lazy(function() {
      return whitespace.then(P.alt([
        object,
        array,
        stringLiteral,
        numberLiteral,
        nullLiteral,
        trueLiteral,
        falseLiteral
      ]));
    }));

    return json.parse(text);
  }
}