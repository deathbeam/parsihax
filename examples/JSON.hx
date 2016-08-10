package examples;

import Parsihax as P;
import Parsihax.Parser;

class JSON {
    public static function main() {
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

        // Use the JSON standard's definition of whitespace rather than Parsihex's.
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
        var nullLiteral = token(P.string('null')).result(null);
        var trueLiteral = token(P.string('true')).result(true);
        var falseLiteral = token(P.string('false')).result(false);

        // Regexp based parsers should generally be named for better error reporting.
        var stringLiteral =
            token(P.regexp(~/"((?:\\.|.)*?)"/, 1))
                .map(interpretEscapes)
                .desc('string');

        var numberLiteral =
            token(P.regexp(~/-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?/))
                .map(function (result) { return Std.parseInt(result); })
                .desc('number');
        
        var object = null;
        var array = null;

        // This is the main entry point of the parser: a full JSON document.
        var json = P.lazy(function() {
            return whitespace.then(P.alt([
                object,
                array,
                stringLiteral,
                numberLiteral,
                nullLiteral,
                trueLiteral,
                falseLiteral
            ]));
        });

        // Array parsing is just ignoring brackets and commas and parsing as many nested
        // JSON documents as possible. Notice that we're using the parser `json` we just
        // defined above. Arrays and objects in the JSON grammar are recursive because
        // they can contain any other JSON document within them.
        array = lbracket.then(commaSep(json)).skip(rbracket);

        // Object parsing is a little trickier because we have to collect all the key-
        // value pairs in order as length-2 arrays, then manually copy them into an
        // object.
        var pair = P.seq([stringLiteral.skip(colon), json]);

        object =
            lbrace.then(commaSep(pair)).skip(rbrace).map(function(pairs) {
                var out = new Map<String, Dynamic>();
                var rPairs : Array<Dynamic> = pairs;

                for (pair in rPairs) {
                    out[pair[0]] = pair[1];
                }

                return out;
            });

        ///////////////////////////////////////////////////////////////////////
        // TODO: Mixing numberLiteral and stringLiteral is for some reason not working
        var text = '{
    "firstName": "John",
    "lastName": "Smith",
    "age": "25",
    "address":
    {
        "streetAddress": "21 2nd Street",
        "city": "New York",
        "state": "NY",
        "postalCode": "10021"
    },
    "phoneNumber":
    [
        {
        "type": "home",
        "number": "212 555-1234"
        },
        {
        "type": "fax",
        "number": "646 555-4567"
        }
    ]
}';

        var result = json.parse(text);

        if (result.status) {
            var val : Map<String, Dynamic> = result.value;
            trace(val);
        } else {
            trace(P.formatError(text, result));
        }
    }
}