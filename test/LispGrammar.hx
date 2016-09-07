import Parsihax.*;
using Parsihax;
using LispGrammar;

// ADT definition
enum LispExpression {
  LispNumber(v: Float);
  LispSymbol(v: String);
  LispString(v: String);
  LispList(v : Array<LispExpression>);
}

class LispGrammar {
  // A little helper to wrap a parser with optional whitespace.
  private static inline function trim(parser : Parser<String>) {
    return parser.skip(optWhitespace());
  }

  public static function build() {
    // We need to use `empty` here because the other parsers don't exist yet. We
    // can't just declare this later though, because `LList` references this parser!
    var LExpression = empty();

    // The basic parsers (usually the ones described via regexp) should have a
    // description for error message purposes.

    var LString =
      ~/"[^"]*"/.regexp().trim()
      .map(function(r) return LispString(r))
      .desc('string');

    var LSymbol =
      ~/[a-zA-Z_-][a-zA-Z0-9_-]*/.regexp().trim()
      .map(function(r) return LispSymbol(r))
      .desc('symbol');

    var LNumber =
      ~/(?=.)([+-]?([0-9]*)(\.([0-9]+))?)/.regexp().trim()
      .map(function(r) return LispNumber(Std.parseFloat(r)))
      .desc('number');

    // `.then` throws away the first value, and `.skip` throws away the second
    // `.value, so we're left with just the `LExpression.many()` part as the
    // `.yielded value from this parser.
    var LList =
      '('.string().trim()
      .then(LExpression.many())
      .skip(')'.string().trim())
      .map(function(r) return LispList(r));

    // Initialize LExpression now because of before recursion by modifying magical .apply field
    LExpression.apply = [
      LSymbol,
      LNumber,
      LString,
      LList
    ].choice();

    // Let's remember to throw away whitespace at the top level of the parser.
    return optWhitespace().then(LExpression).apply;
  }
}