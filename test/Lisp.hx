package test;

import parsihax.Parser;
import parsihax.Parser.Ref;
import parsihax.Parser as P;

class Lisp {
  public static function parse(text : String) {
    // A little helper to wrap a parser with optional whitespace.
    function spaced(parser) {
      return P.optWhitespace().then(parser).skip(P.optWhitespace());
    }

    // We need to use `P.ref` here because the other parsers don't exist yet. We
    // can't just declare this later though, because `LList` references this parser!
    var LExpression : Ref<Dynamic> = P.ref();

    // The basic parsers (usually the ones described via regexp) should have a
    // description for error message purposes.
    var LSymbol : Parser<Dynamic> = P.regexp(~/[a-zA-Z_-][a-zA-Z0-9_-]*/).desc('symbol');
    var LNumber : Parser<Dynamic> = P.regexp(~/[0-9]+/).map(function (result) { return Std.parseInt(result); }).desc('number');

    // `.then` throws away the first value, and `.skip` throws away the second
    // `.value, so we're left with just the `spaced(LExpression).many()` part as the
    // `.yielded value from this parser.
    var LList : Parser<Array<Dynamic>> =
      P.string('(')
        .then(spaced(LExpression).many())
        .skip(P.string(')'));

    LExpression.set(P.lazy(function() {
        return P.alt([
          LSymbol,
          LNumber,
          LList
        ]);
      }));

    // Let's remember to throw away whitespace at the top level of the parser.
    var lisp = spaced(LExpression);


    return lisp.parse(text);
  }
}