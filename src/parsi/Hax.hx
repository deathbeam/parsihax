package parsi;

import haxe.ds.Vector;
using parsi.Hax;

/**
  A structure with a boolean `status` flag, indicating whether the parse
  succeeded. If it succeeded, the `value` attribute will contain the yielded
  value. Otherwise, the `index` and `expected` attributes will contain the
  offset of the parse error, and a sorted, unique array of messages indicating
  what was expected.

  The error structure can be passed along with the original source to
  `Hax.formatError` to obtain a human-readable error string.
**/
typedef Result<T> = {
  /**
    Flag, indicating whether the parse succeeded
  **/
  var status : Bool;

  /**
    Offset of the parse error (in case of failed parse)
  **/
  var index : Int;

  /**
    Yielded value of `Parser` (in case of successfull parse)
  **/
  var value : T;

  /**
    Offset of last parse
  **/
  var furthest : Int;

  /**
    A sorted, unique array of messages indicating what was expected (in case of failed parse)
  **/
  var expected : Array<String>;
};

/**
  Parsing function created by chaining Hax combinators.
**/
typedef Function<A> = String -> ?Int -> Result<A>;

/**
  The Parser object is a wrapper for a parser function.
  Externally, you use one to parse a string by calling
    `var result = SomeParser.apply('Me Me Me! Parse Me!');`
**/
abstract Parser<T>(Vector<Function<T>>) {
  inline function new() this = new Vector(1);
  @:to inline function get_apply() : Function<T> return this[0];
  inline function set_apply(param : Function<T>) return this[0] = param;

  /**
    Getting `Parser.apply` from a parser (or explicitly casting it to
    `Function` returns parsing function `String -> ?Int -> Result<A>`
    (or just `Function`), that parses the string and returns `Result<A>`.

    Changing `Parser.apply` value changes parser behaviour, but still keeps it's
    reference, what is really usefull in recursive parsers.
  **/
  public var apply(get, set): Function<T>;

  /**
    Creates `Parser` from `Function`
  **/
  @:noUsing @:from static inline public function to<T>(v : Function<T>) : Parser<T> {
    var ret = new Parser();
    ret.apply = v;
    return ret;
  }

  /**
    Same as `Hax.then(l, r)`
  **/
  @:noUsing @:op(A + B) static inline public function opAdd<A, B>(l: Parser<A>, r: Parser<B>): Parser<B> {
    return Hax.then(l, r);
  }

  /**
    Same as `Hax.or(l, r)`
  **/
  @:noUsing @:op(A | B) static inline public function opOr<A>(l: Parser<A>, r: Parser<A>): Parser<A> {
    return Hax.or(l, r);
  }

  /**
    Same as `Hax.as(l, r)`
  **/
  @:noUsing @:op(A / B) static inline public function opDiv<A>(l: Parser<A>, r: String): Parser<A> {
    return Hax.as(l, r);
  }

}

/**
  Defines grammar and encapsulates parsing logic. A `Parser` takes as input a
  `String` source and parses it when the `Parser.apply` method is called.
  A structure `Result` is returned.
**/
class Hax {
  /**
    Equivalent to `Hax.regexp(~/[a-z]/i)`
  **/
  inline public static function letter() : Parser<String> {
    return ~/[a-z]/i.regexp().as('a letter');
  }

  /**
    Equivalent to `Hax.regexp(~/[a-z]* /i)`
  **/
  inline public static function letters() : Parser<String> {
    return ~/[a-z]*/i.regexp();
  }

  /**
    Equivalent to `Hax.regexp(~/[0-9]/)`
  **/
  inline public static function digit() : Parser<String> {
    return ~/[0-9]/.regexp().as('a digit');
  }

  /**
    Equivalent to `Hax.regexp(~/[0-9]* /)`
  **/
  inline public static function digits() : Parser<String> {
    return ~/[0-9]*/.regexp();
  }

  /**
    Equivalent to `Hax.regexp(~/\s+/)`
  **/
  inline public static function whitespace() : Parser<String> {
    return ~/\s+/.regexp().as('whitespace');
  }

  /**
    Equivalent to `Hax.regexp(~/\s* /)`
  **/
  inline public static function optWhitespace() : Parser<String> {
    return ~/\s*/.regexp();
  }

  /**
    A `Parser` that consumes and yields the next character of the stream.
  **/
  public static function any() : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      return i >= stream.length
        ? makeFailure(i, 'any character')
        : makeSuccess(i+1, stream.charAt(i));
    };
  }

  /**
    A `Parser` that consumes and yields the entire remainder of the stream.
  **/
  public static function all() : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      return makeSuccess(stream.length, stream.substring(i));
    };
  }

  /**
    A `Parser` that expects to be at the end of the stream (zero characters left).
  **/
  public static function eof<A>() : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      return i < stream.length
        ? makeFailure(i, 'EOF')
        : makeSuccess(i, null);
    };
  }

  /**
    Returns a `Parser` that looks for `String` and yields that exact value.
  **/
  public static function string(string : String) : Parser<String> {
    var len = string.length;
    var expected = "'"+string+"'";

    return function(stream : String, i : Int = 0) : Result<String> {
      var head = stream.substring(i, i + len);

      if (head == string) {
        return makeSuccess(i+len, head);
      } else {
        return makeFailure(i, expected);
      }
    };
  }

  /**
    Returns a `Parser` that looks for exactly one character from `String` and
    yields that exact value. This combinator is faster than `Hax.string`
    in case of matching single character.
  **/
  public static function char(character : String) : Parser<String> {
    return function(ch) { return character == ch; }.test().as("'"+character+"'");
  }

  /**
    Returns a `Parser` that looks for exactly one character from `String`, and
    yields that character.
  **/
  public static function oneOf(string : String) : Parser<String> {
    return function(ch) { return string.indexOf(ch) >= 0; }.test();
  }

  /**
    Returns a `Parser` that looks for exactly one character NOT from `String`,
    and yields that character.
  **/
  public static function noneOf(string : String) : Parser<String> {
    return function(ch) { return string.indexOf(ch) < 0; }.test();
  }

  /**
    Returns a `Parser` that looks for a match to the `EReg` and yields the given
    match group (defaulting to the entire match). The `EReg` will always match
    starting at the current parse location. The regexp may only use the
    following flags: imu. Any other flag will result in some weird behaviour.
  **/
  public static function regexp(re : EReg, group : Int = 0) : Parser<String> {
    var expected = Std.string(re);

    return function(stream : String, i : Int = 0) : Result<String> {
      var match = re.match(stream.substring(i));

      if (match) {
        var groupMatch = re.matched(group);
        var pos = re.matchedPos();
        if (groupMatch != null && pos.pos == 0) {
          return makeSuccess(i + pos.len, groupMatch);
        }
      }

      return makeFailure(i, expected);
    };
  }

  /**
    Returns a `Parser` that doesn't consume any of the string, and yields
    `value`.
  **/
  public static function succeed<A>(value : A) : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      return makeSuccess(i, value);
    };
  }

  /**
    Returns a failing `Parser` with the given `expected` message.
  **/
  public static function fail<A>(expected : String) : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      return makeFailure(i, expected);
    }
  }

  /**
    Returns a new failed `Parser` with 'empty' message
  **/
  public static function empty<A>() : Parser<A> {
    return fail('empty');
  }

  /**
    Accepts an array of parsers `Array<Parser>` and returns a new
    `Parser<Array>` that expects them to match in order, yielding an array of
    all their results.
  **/
  public static function seq<A>(parsers : Array<Parser<A>>) : Parser<Array<A>> {
    if (parsers.length == 0) return fail('sequence of parsers');

    return function(stream : String, i : Int = 0) : Result<Array<A>> {
      var result : Result<A> = null;
      var accum : Array<A> = [];

      for (parser in parsers) {
        result = mergeReplies(parser.apply(stream, i), result);
        if (!result.status) return cast(result);
        accum.push(result.value);
        i = result.index;
      }

      return mergeReplies(makeSuccess(i, accum), result);
    };
  }

  /**
    Accepts an array of parsers `Array<Parser>`, yielding the value of the first
    one that succeeds, backtracking in between. This means that the order of
    parsers matters. If two parsers match the same prefix, the longer of the two
    must come first.

    ```haxe
    Hax.alt([
      Hax.string('ab'),
      Hax.string('a')
    ]).apply('ab');
    // => {status: true, value: 'ab'}

    Hax.alt([
      Hax.string('a'),
      Hax.string('ab')
    ]).apply('ab');
    // => {status: false, ...}
    ```

    In the second case, `Hax.alt` matches on the first parser, then
    there are extra characters left over (`'b'`), so `Parser` returns a failure.
  **/
  public static function alt<A>(parsers : Array<Parser<A>>) : Parser<A> {
    if (parsers.length == 0) return fail('at least one alt');

    return function(stream : String, i : Int = 0) : Result<A> {
      var result : Result<A> = null;

      for (parser in parsers) {
        result = mergeReplies(parser.apply(stream, i), result);
        if (result.status) return result;
      }

      return result;
    };
  }

  /**
    Accepts two `Parser`s, and expects zero or more matches for content,
    separated by `separator`, yielding an array.

    ```haxe
    Hax.sepBy(
      Hax.oneOf('abc'),
      Hax.string('|')
    ).apply('a|b|c|c|c|a');
    // => {status: true, value: ['a', 'b', 'c', 'c', 'c', 'a']}

    Hax.sepBy(
      Hax.oneOf('XYZ'),
      Hax.string('-')
    ).apply('');
    // => {status: true, value: []}
    ```
  **/
  inline public static function sepBy<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    return parser.sepBy1(separator).or([].succeed());
  }

  /**
    This is the same as `Parser.sepBy`, but matches the content parser at least
    once.
  **/
  public static function sepBy1<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    var pairs = separator.then(parser).many();

    return parser.flatMap(function(r) {
      return pairs.map(function(rs) {
        return [r].concat(rs);
      });
    });
  }

  /**
    Accepts a function that returns a `Parser`, which is evaluated the first
    time the parser is used. This is useful for referencing parsers that haven't
    yet been defined, and for implementing recursive parsers.

    ```haxe
    static var Value = Hax.lazy(function() {
      return Hax.alt([
        Hax.string('x'),
        Hax.string('(')
          .then(Value)
          .skip(Hax.string(')'))
      ]);
    });

    // ...
    Value.apply('X');     // => {status: true, value: 'X'}
    Value.apply('(X)');   // => {status: true, value: 'X'}
    Value.apply('((X))'); // => {status: true, value: 'X'}
    ```
  **/
  public static function lazy<A>(fun : Void -> Parser<A>) : Parser<A> {
    var parser : Parser<A> = null;

    return parser = function(stream : String, i : Int = 0) : Result<A> {
      return (parser.apply = fun().apply)(stream, i);
    };
  }

  /**
    Returns a `Parser` that yield a single character if it passes the `predicate`
    function `String -> Bool`.

    ```haxe
    var SameUpperLower = Hax.test(function(c) {
      return c.toUpperCase() == c.toLowerCase();
    });

    SameUpperLower.apply('a'); // => {status: false, ...}
    SameUpperLower.apply('-'); // => {status: true, ...}
    SameUpperLower.apply(':'); // => {status: true, ...}
    ```
  **/
  public static function test(predicate : String -> Bool) : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      var char = stream.charAt(i);

      return i < stream.length && predicate(char)
        ? makeSuccess(i+1, char)
        : makeFailure(i, 'a character matching ' + predicate);
    };
  }

  /**
    Returns a `Parser` yielding a string containing all the next characters that
    pass the `predicate : String -> Bool`.

    ```haxe
    var CustomString =
      Hax.string('%')
        .then(Hax.any())
        .flatMap(function(start) {
          var end = [
            '[' => ']',
            '(' => ')',
            '{' => '}',
            '<'=> '>'
          ][start];
          end = end != null ? end : start;

          return Hax.takeWhile(function(c) {
            return c != end;
          }).skip(Hax.string(end));
        });

    CustomString.apply('%:a string:'); // => {status: true, value: 'a string'}
    CustomString.apply('%[a string]'); // => {status: true, value: 'a string'}
    CustomString.apply('%{a string}'); // => {status: true, value: 'a string'}
    CustomString.apply('%(a string)'); // => {status: true, value: 'a string'}
    CustomString.apply('%<a string>'); // => {status: true, value: 'a string'}
    ```
  **/
  public static function takeWhile(predicate : String -> Bool) : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      var j = i;
      while (j < stream.length && predicate(stream.charAt(j))) j += 1;
      return makeSuccess(j, stream.substring(i, j));
    };
  }

  /**
    Returns a new `Parser` which tries `parser`, and if it fails uses
    `alternative`. Example:

    ```haxe
    var numberPrefix =
      Hax.string('+')
        .or(Hax.of('-'))
        .or(Hax.of(''));

    numberPrefix.apply('+'); // => {status: true, value: '+'}
    numberPrefix.apply('-'); // => {status: true, value: '-'}
    numberPrefix.apply('');  // => {status: true, value: ''}
    ```
  **/
  public static function or<A>(parser: Parser<A>, alternative : Parser<A>) : Parser<A> {
    return [parser, alternative].alt();
  }

  /**
    Returns a new `Parser` which tries `parser`, and on success calls the function
    `fun : A -> Parser<B>` with the result of the parse, which is expected to
    return another parser, which will be tried next. This allows you to
    dynamically decide how to continue the parse, which is impossible with the
    other combinators.

    ```haxe
    var CustomString =
      Hax.string('%')
        .then(Hax.any())
        .flatMap(function(start) {
          var end = [
            '[' => ']',
            '(' => ')',
            '{' => '}',
            '<'=> '>'
          ][start];
          end = end != null ? end : start;

          return Hax.takeWhile(function(c) {
            return c != end;
          }).skip(Hax.string(end));
        });

    CustomString.apply('%:a string:'); // => {status: true, value: 'a string'}
    CustomString.apply('%[a string]'); // => {status: true, value: 'a string'}
    CustomString.apply('%{a string}'); // => {status: true, value: 'a string'}
    CustomString.apply('%(a string)'); // => {status: true, value: 'a string'}
    CustomString.apply('%<a string>'); // => {status: true, value: 'a string'}
    ```
  **/
  public static function flatMap<A, B>(parser: Parser<A>, fun : A -> Parser<B>) : Parser<B> {
    return function(stream : String, i : Int = 0) : Result<B> {
      var result = parser.apply(stream, i);
      if (!result.status) return cast(result);
      var nextParser = fun(result.value);
      return mergeReplies(nextParser.apply(stream, result.index), result);
    };
  }

  /**
    Expects `next` to follow `parser`, and yields the result of `next`.

    ```haxe
    var parserA = p1.then(p2); // is equivalent to...
    var parserB = Hax.seq([p1, p2]).map(function(results) return results[1]);
    ```
  **/
  public static function then<A, B>(parser: Parser<A>, next : Parser<B>) : Parser<B> {
    return parser.flatMap(function(result) return next);
  }

  /**
    Transforms the output of `parser` with the given function `fun : A -> B`.

    ```haxe
    var pNum = Hax.regexp(~/[0-9]+/).map(Std.applyInt);

    pNum.apply('9');   // => {status: true, value: 9}
    pNum.apply('123'); // => {status: true, value: 123}
    pNum.apply('3.1'); // => {status: true, value: 3.1}
    ```
  **/
  public static function map<A, B>(parser: Parser<A>, fun : A -> B) : Parser<B> {
    return function(stream : String, i : Int = 0) : Result<B> {
      var result = parser.apply(stream, i);
      if (!result.status) return cast(result);
      return mergeReplies(makeSuccess(result.index, fun(result.value)), result);
    };
  }

  /**
    Returns a new `Parser` with the same behavior, but which yields `value`.
    Equivalent to `Hax.map(parser, function(x) return x)`.
  **/
  public static function result<A, B>(parser: Parser<A>, value : B) : Parser<B> {
    return parser.map(function(_) return value);
  }

  /**
    Expects `next` after `parser`, but yields the value of `parser`.

    ```haxe
    var parserA = p1.skip(p2); // is equivalent to...
    var parserB = Hax.seq([p1, p2]).map(function(results) return results[0]);
    ```
  **/
  public static function skip<A, B>(parser: Parser<A>, next : Parser<B>) : Parser<A> {
    return parser.flatMap(function(result) return next.result(result));
  };

  /**
    Expects `Parser` zero or more times, and yields an array of the results.
  **/
  public static function many<A>(parser: Parser<A>) : Parser<Array<A>> {
    return function(stream : String, i : Int = 0) : Result<Array<A>> {
      var accum : Array<A> = [];
      var result = null;

      while (true) {
        result = mergeReplies(parser.apply(stream, i), result);

        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else {
          return mergeReplies(makeSuccess(i, accum), result);
        }
      }
    };
  }

  /**
    Expects `Parser` one or more times, and yields an array of the results.
  **/
  inline public static function many1<A>(parser: Parser<A>) : Parser<Array<A>> {
    return parser.atLeast(1);
  }

  /**
    Expects `Parser` between `min` and `max` times (or exactly `min` times, when
    `max` is omitted), and yields an array of the results.
  **/
  public static function times<A>(parser: Parser<A>, min : Int, ?max : Int) : Parser<Array<A>> {
    if (max == null) max = min;

    return function(stream : String, i : Int = 0) : Result<Array<A>> {
      var accum = [];
      var start = i;
      var result = null;
      var prevResult = null;

      for (times in 0...min) {
        result = parser.apply(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else return cast(prevResult);
      }

      for (times in 0...max) {
        result = parser.apply(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else break;
      }

      return mergeReplies(makeSuccess(i, accum), prevResult);
    };
  }

  /**
    Expects `Parser` at most `n` times. Yields an array of the results.
  **/
  inline public static function atMost<A>(parser: Parser<A>, n : Int) : Parser<Array<A>> {
    return parser.times(0, n);
  }

  /**
    Expects `Parser` at least `n` times. Yields an array of the results.
  **/
  public static function atLeast<A>(parser: Parser<A>, n : Int) : Parser<Array<A>> {
    return [parser.times(n), parser.many()].seq().map(function(results) {
      return results[0].concat(results[1]);
    });
  }

  /**
    Yields current position in stream
  **/
  public static function index() : Parser<Int> {
    return function(stream : String, i : Int = 0) : Result<Int> {
      return makeSuccess(i, i);
    };
  }

  /**
    Returns a new `Parser` whose failure message is expected parameter. For example,
    `string('x').as('the letter x')` will indicate that 'the letter x' was
    expected.
  **/
  public static function as<A>(parser: Parser<A>, expected : String) : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      var reply = parser.apply(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    };
  }

  /**
    Obtain a human-readable error `String`.
  **/
  public static function formatError<T>(result : Result<T>, stream : String) : String {
    var sexpected = result.expected.length == 1
      ? result.expected[0]
      : 'one of ' + result.expected.join(', ');

    var indexOffset = result.furthest;
    var lines = stream.substring(0, indexOffset).split("\n");
    var lineWeAreUpTo = lines.length;
    var columnWeAreUpTo = lines[lines.length - 1].length + 1;

    var got = '';

    if (indexOffset == stream.length) {
      got = ', got the end of the stream';
    } else {
      var prefix = (indexOffset > 0 ? "'..." : "'");
      var suffix = (stream.length - indexOffset > 12 ? "...'" : "'");

      got = ' at line ' + lineWeAreUpTo + ' column ' + columnWeAreUpTo
        +  ', got ' + prefix + stream.substring(indexOffset, indexOffset + 12) + suffix;
    }

    return 'expected ' + sexpected + got;
  }

  /**
    Create successfull `Result` with specified `index` and `value`.
  **/
  inline private static function makeSuccess<A>(index : Int, value : A) : Result<A> {
    return {
      status: true,
      index: index,
      value: value,
      furthest: -1,
      expected: []
    };
  }

  /**
    Create failed `Result` with specified `index` and `expected` input.
  **/
  inline private static function makeFailure<A>(index : Int, expected : String) : Result<A> {
    return {
      status: false,
      index: -1,
      value: null,
      furthest: index,
      expected: [expected]
    };
  }

  /**
    Merge `result` and `last` into single `Result`.
  **/
  private static function mergeReplies<A, B>(result : Result<A>, ?last : Result<B>) : Result<A> {
    if (last == null) return result;
    if (result.furthest > last.furthest) return result;

    var expected = (result.furthest == last.furthest)
      ? unsafeUnion(result.expected, last.expected)
      : last.expected;

    return {
      status: result.status,
      index: result.index,
      value: result.value,
      furthest: last.furthest,
      expected: expected
    }
  }

  /**
    Create unsafe union from two string arrays `xs` and `ys`.
  **/
  private static function unsafeUnion(xs : Array<String>, ys : Array<String>) : Array<String> {
    if (xs.length == 0) {
      return ys;
    } else if (ys.length == 0) {
      return xs;
    }

    var result = xs.concat(ys);

    result.sort(function(a, b):Int {
        a = a.toLowerCase();
        b = b.toLowerCase();
        if (a < b) return -1;
        if (a > b) return 1;
        return 0;
    });

    return result;
  }
}
