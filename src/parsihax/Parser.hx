package parsihax;

using parsihax.Parser;

/**
  Defines grammar and encapsulates parsing logic. A `ParseObject` takes as input a
  `String` source and parses it when the `ParseObject.apply` method is called.
  A structure `ParseResult` is returned.
**/
class Parser {
  /**
    Equivalent to `Parser.regexp(~/[a-z]/i)`
  **/
  inline public static function letter() : ParseObject<String> {
    return ~/[a-z]/i.regexp().as('a letter');
  }

  /**
    Equivalent to `Parser.regexp(~/[a-z]* /i)`
  **/
  inline public static function letters() : ParseObject<String> {
    return ~/[a-z]*/i.regexp();
  }

  /**
    Equivalent to `Parser.regexp(~/[0-9]/)`
  **/
  inline public static function digit() : ParseObject<String> {
    return ~/[0-9]/.regexp().as('a digit');
  }

  /**
    Equivalent to `Parser.regexp(~/[0-9]* /)`
  **/
  inline public static function digits() : ParseObject<String> {
    return ~/[0-9]*/.regexp();
  }

  /**
    Equivalent to `Parser.regexp(~/\s+/)`
  **/
  inline public static function whitespace() : ParseObject<String> {
    return ~/\s+/.regexp().as('whitespace');
  }

  /**
    Equivalent to `Parser.regexp(~/\s* /)`
  **/
  inline public static function optWhitespace() : ParseObject<String> {
    return ~/\s*/.regexp();
  }

  /**
    A `ParseObject` that consumes and yields the next character of the stream.
  **/
  public static function any() : ParseObject<String> {
    return function(stream : String, i : Int = 0) : ParseResult<String> {
      return i >= stream.length
        ? makeFailure(i, 'any character')
        : makeSuccess(i+1, stream.charAt(i));
    };
  }

  /**
    A `ParseObject` that consumes and yields the entire remainder of the stream.
  **/
  public static function all() : ParseObject<String> {
    return function(stream : String, i : Int = 0) : ParseResult<String> {
      return makeSuccess(stream.length, stream.substring(i));
    };
  }

  /**
    A `ParseObject` that expects to be at the end of the stream (zero characters left).
  **/
  public static function eof<A>() : ParseObject<A> {
    return function(stream : String, i : Int = 0) : ParseResult<A> {
      return i < stream.length
        ? makeFailure(i, 'EOF')
        : makeSuccess(i, null);
    };
  }

  /**
    Returns a `ParseObject` that looks for `String` and yields that exact value.
  **/
  public static function string(string : String) : ParseObject<String> {
    var len = string.length;
    var expected = "'"+string+"'";

    return function(stream : String, i : Int = 0) : ParseResult<String> {
      var head = stream.substring(i, i + len);

      if (head == string) {
        return makeSuccess(i+len, head);
      } else {
        return makeFailure(i, expected);
      }
    };
  }

  /**
    Returns a `ParseObject` that looks for exactly one character from `String` and
    yields that exact value. This combinator is faster than `Parser.string`
    in case of matching single character.
  **/
  public static function char(character : String) : ParseObject<String> {
    return function(ch) { return character == ch; }.test().as("'"+character+"'");
  }

  /**
    Returns a `ParseObject` that looks for exactly one character from `String`, and
    yields that character.
  **/
  public static function oneOf(string : String) : ParseObject<String> {
    return function(ch) { return string.indexOf(ch) >= 0; }.test();
  }

  /**
    Returns a `ParseObject` that looks for exactly one character NOT from `String`,
    and yields that character.
  **/
  public static function noneOf(string : String) : ParseObject<String> {
    return function(ch) { return string.indexOf(ch) < 0; }.test();
  }

  /**
    Returns a `ParseObject` that looks for a match to the `EReg` and yields the given
    match group (defaulting to the entire match). The `EReg` will always match
    starting at the current parse location. The regexp may only use the
    following flags: imu. Any other flag will result in some weird behaviour.
  **/
  public static function regexp(re : EReg, group : Int = 0) : ParseObject<String> {
    var expected = Std.string(re);

    return function(stream : String, i : Int = 0) : ParseResult<String> {
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
    Returns a `ParseObject` that doesn't consume any of the string, and yields
    `value`.
  **/
  public static function succeed<A>(value : A) : ParseObject<A> {
    return function(stream : String, i : Int = 0) : ParseResult<A> {
      return makeSuccess(i, value);
    };
  }

  /**
    Returns a failing `ParseObject` with the given `expected` message.
  **/
  public static function fail<A>(expected : String) : ParseObject<A> {
    return function(stream : String, i : Int = 0) : ParseResult<A> {
      return makeFailure(i, expected);
    }
  }

  /**
    Returns a new failed `ParseObject` with 'empty' message
  **/
  public static function empty<A>() : ParseObject<A> {
    return fail('empty');
  }

  /**
    Accepts an array of parsers `Array<ParseObject>` and returns a new
    `ParseObject<Array>` that expects them to match in order, yielding an array of
    all their results.
  **/
  public static function seq<A>(parsers : Array<ParseObject<A>>) : ParseObject<Array<A>> {
    if (parsers.length == 0) return fail('sequence of parsers');

    return function(stream : String, i : Int = 0) : ParseResult<Array<A>> {
      var result : ParseResult<A> = null;
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
    Accepts an array of parsers `Array<ParseObject>`, yielding the value of the first
    one that succeeds, backtracking in between. This means that the order of
    parsers matters. If two parsers match the same prefix, the longer of the two
    must come first.

    ```haxe
    Parser.alt([
      Parser.string('ab'),
      Parser.string('a')
    ]).apply('ab');
    // => {status: true, value: 'ab'}

    Parser.alt([
      Parser.string('a'),
      Parser.string('ab')
    ]).apply('ab');
    // => {status: false, ...}
    ```

    In the second case, `Parser.alt` matches on the first parser, then
    there are extra characters left over (`'b'`), so `ParseObject` returns a failure.
  **/
  public static function alt<A>(parsers : Array<ParseObject<A>>) : ParseObject<A> {
    if (parsers.length == 0) return fail('at least one alt');

    return function(stream : String, i : Int = 0) : ParseResult<A> {
      var result : ParseResult<A> = null;

      for (parser in parsers) {
        result = mergeReplies(parser.apply(stream, i), result);
        if (result.status) return result;
      }

      return result;
    };
  }

  /**
    Accepts two `ParseObject`s, and expects zero or more matches for content,
    separated by `separator`, yielding an array.

    ```haxe
    Parser.sepBy(
      Parser.oneOf('abc'),
      Parser.string('|')
    ).apply('a|b|c|c|c|a');
    // => {status: true, value: ['a', 'b', 'c', 'c', 'c', 'a']}

    Parser.sepBy(
      Parser.oneOf('XYZ'),
      Parser.string('-')
    ).apply('');
    // => {status: true, value: []}
    ```
  **/
  inline public static function sepBy<A, B>(parser : ParseObject<A>, separator : ParseObject<B>) : ParseObject<Array<A>> {
    return parser.sepBy1(separator).or([].succeed());
  }

  /**
    This is the same as `ParseObject.sepBy`, but matches the content parser at least
    once.
  **/
  public static function sepBy1<A, B>(parser : ParseObject<A>, separator : ParseObject<B>) : ParseObject<Array<A>> {
    var pairs = separator.then(parser).many();

    return parser.flatMap(function(r) {
      return pairs.map(function(rs) {
        return [r].concat(rs);
      });
    });
  }

  /**
    Accepts a function that returns a `ParseObject`, which is evaluated the first
    time the parser is used. This is useful for referencing parsers that haven't
    yet been defined, and for implementing recursive parsers.

    ```haxe
    static var Value = Parser.lazy(function() {
      return Parser.alt([
        Parser.string('x'),
        Parser.string('(')
          .then(Value)
          .skip(Parser.string(')'))
      ]);
    });

    // ...
    Value.apply('X');     // => {status: true, value: 'X'}
    Value.apply('(X)');   // => {status: true, value: 'X'}
    Value.apply('((X))'); // => {status: true, value: 'X'}
    ```
  **/
  public static function lazy<A>(fun : Void -> ParseObject<A>) : ParseObject<A> {
    var parser : ParseObject<A> = null;

    return parser = function(stream : String, i : Int = 0) : ParseResult<A> {
      return (parser.apply = fun().apply)(stream, i);
    };
  }

  /**
    Returns a `ParseObject` that yield a single character if it passes the `predicate`
    function `String -> Bool`.

    ```haxe
    var SameUpperLower = Parser.test(function(c) {
      return c.toUpperCase() == c.toLowerCase();
    });

    SameUpperLower.apply('a'); // => {status: false, ...}
    SameUpperLower.apply('-'); // => {status: true, ...}
    SameUpperLower.apply(':'); // => {status: true, ...}
    ```
  **/
  public static function test(predicate : String -> Bool) : ParseObject<String> {
    return function(stream : String, i : Int = 0) : ParseResult<String> {
      var char = stream.charAt(i);

      return i < stream.length && predicate(char)
        ? makeSuccess(i+1, char)
        : makeFailure(i, 'a character matching ' + predicate);
    };
  }

  /**
    Returns a `ParseObject` yielding a string containing all the next characters that
    pass the `predicate : String -> Bool`.

    ```haxe
    var CustomString =
      Parser.string('%')
        .then(Parser.any())
        .flatMap(function(start) {
          var end = [
            '[' => ']',
            '(' => ')',
            '{' => '}',
            '<'=> '>'
          ][start];
          end = end != null ? end : start;

          return Parser.takeWhile(function(c) {
            return c != end;
          }).skip(Parser.string(end));
        });

    CustomString.apply('%:a string:'); // => {status: true, value: 'a string'}
    CustomString.apply('%[a string]'); // => {status: true, value: 'a string'}
    CustomString.apply('%{a string}'); // => {status: true, value: 'a string'}
    CustomString.apply('%(a string)'); // => {status: true, value: 'a string'}
    CustomString.apply('%<a string>'); // => {status: true, value: 'a string'}
    ```
  **/
  public static function takeWhile(predicate : String -> Bool) : ParseObject<String> {
    return function(stream : String, i : Int = 0) : ParseResult<String> {
      var j = i;
      while (j < stream.length && predicate(stream.charAt(j))) j += 1;
      return makeSuccess(j, stream.substring(i, j));
    };
  }

  /**
    Returns a new `ParseObject` which tries `parser`, and if it fails uses
    `alternative`. Example:

    ```haxe
    var numberPrefix =
      Parser.string('+')
        .or(Parser.of('-'))
        .or(Parser.of(''));

    numberPrefix.apply('+'); // => {status: true, value: '+'}
    numberPrefix.apply('-'); // => {status: true, value: '-'}
    numberPrefix.apply('');  // => {status: true, value: ''}
    ```
  **/
  public static function or<A>(parser: ParseObject<A>, alternative : ParseObject<A>) : ParseObject<A> {
    return [parser, alternative].alt();
  }

  /**
    Returns a new `ParseObject` which tries `parser`, and on success calls the function
    `fun : A -> ParseObject<B>` with the result of the parse, which is expected to
    return another parser, which will be tried next. This allows you to
    dynamically decide how to continue the parse, which is impossible with the
    other combinators.

    ```haxe
    var CustomString =
      Parser.string('%')
        .then(Parser.any())
        .flatMap(function(start) {
          var end = [
            '[' => ']',
            '(' => ')',
            '{' => '}',
            '<'=> '>'
          ][start];
          end = end != null ? end : start;

          return Parser.takeWhile(function(c) {
            return c != end;
          }).skip(Parser.string(end));
        });

    CustomString.apply('%:a string:'); // => {status: true, value: 'a string'}
    CustomString.apply('%[a string]'); // => {status: true, value: 'a string'}
    CustomString.apply('%{a string}'); // => {status: true, value: 'a string'}
    CustomString.apply('%(a string)'); // => {status: true, value: 'a string'}
    CustomString.apply('%<a string>'); // => {status: true, value: 'a string'}
    ```
  **/
  public static function flatMap<A, B>(parser: ParseObject<A>, fun : A -> ParseObject<B>) : ParseObject<B> {
    return function(stream : String, i : Int = 0) : ParseResult<B> {
      var result = parser.apply(stream, i);
      if (!result.status) return cast(result);
      var nextParseObject = fun(result.value);
      return mergeReplies(nextParseObject.apply(stream, result.index), result);
    };
  }

  /**
    Expects `next` to follow `parser`, and yields the result of `next`.

    ```haxe
    var parserA = p1.then(p2); // is equivalent to...
    var parserB = Parser.seq([p1, p2]).map(function(results) return results[1]);
    ```
  **/
  public static function then<A, B>(parser: ParseObject<A>, next : ParseObject<B>) : ParseObject<B> {
    return parser.flatMap(function(result) return next);
  }

  /**
    Transforms the output of `parser` with the given function `fun : A -> B`.

    ```haxe
    var pNum = Parser.regexp(~/[0-9]+/).map(Std.applyInt);

    pNum.apply('9');   // => {status: true, value: 9}
    pNum.apply('123'); // => {status: true, value: 123}
    pNum.apply('3.1'); // => {status: true, value: 3.1}
    ```
  **/
  public static function map<A, B>(parser: ParseObject<A>, fun : A -> B) : ParseObject<B> {
    return function(stream : String, i : Int = 0) : ParseResult<B> {
      var result = parser.apply(stream, i);
      if (!result.status) return cast(result);
      return mergeReplies(makeSuccess(result.index, fun(result.value)), result);
    };
  }

  /**
    Returns a new `ParseObject` with the same behavior, but which yields `value`.
    Equivalent to `Parser.map(parser, function(x) return x)`.
  **/
  public static function result<A, B>(parser: ParseObject<A>, value : B) : ParseObject<B> {
    return parser.map(function(_) return value);
  }

  /**
    Expects `next` after `parser`, but yields the value of `parser`.

    ```haxe
    var parserA = p1.skip(p2); // is equivalent to...
    var parserB = Parser.seq([p1, p2]).map(function(results) return results[0]);
    ```
  **/
  public static function skip<A, B>(parser: ParseObject<A>, next : ParseObject<B>) : ParseObject<A> {
    return parser.flatMap(function(result) return next.result(result));
  };

  /**
    Expects `ParseObject` zero or more times, and yields an array of the results.
  **/
  public static function many<A>(parser: ParseObject<A>) : ParseObject<Array<A>> {
    return function(stream : String, i : Int = 0) : ParseResult<Array<A>> {
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
    Expects `ParseObject` one or more times, and yields an array of the results.
  **/
  inline public static function many1<A>(parser: ParseObject<A>) : ParseObject<Array<A>> {
    return parser.atLeast(1);
  }

  /**
    Expects `ParseObject` between `min` and `max` times (or exactly `min` times, when
    `max` is omitted), and yields an array of the results.
  **/
  public static function times<A>(parser: ParseObject<A>, min : Int, ?max : Int) : ParseObject<Array<A>> {
    if (max == null) max = min;

    return function(stream : String, i : Int = 0) : ParseResult<Array<A>> {
      var accum = [];
      var start = i;
      var result = null;
      var prevParseResult = null;

      for (times in 0...min) {
        result = parser.apply(stream, i);
        prevParseResult = mergeReplies(result, prevParseResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else return cast(prevParseResult);
      }

      for (times in 0...max) {
        result = parser.apply(stream, i);
        prevParseResult = mergeReplies(result, prevParseResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else break;
      }

      return mergeReplies(makeSuccess(i, accum), prevParseResult);
    };
  }

  /**
    Expects `ParseObject` at most `n` times. Yields an array of the results.
  **/
  inline public static function atMost<A>(parser: ParseObject<A>, n : Int) : ParseObject<Array<A>> {
    return parser.times(0, n);
  }

  /**
    Expects `ParseObject` at least `n` times. Yields an array of the results.
  **/
  public static function atLeast<A>(parser: ParseObject<A>, n : Int) : ParseObject<Array<A>> {
    return [parser.times(n), parser.many()].seq().map(function(results) {
      return results[0].concat(results[1]);
    });
  }

  /**
    Yields current position in stream
  **/
  public static function index() : ParseObject<Int> {
    return function(stream : String, i : Int = 0) : ParseResult<Int> {
      return makeSuccess(i, i);
    };
  }

  /**
    Returns a new `ParseObject` whose failure message is expected parameter. For example,
    `string('x').as('the letter x')` will indicate that 'the letter x' was
    expected.
  **/
  public static function as<A>(parser: ParseObject<A>, expected : String) : ParseObject<A> {
    return function(stream : String, i : Int = 0) : ParseResult<A> {
      var reply = parser.apply(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    };
  }

  /**
    Obtain a human-readable error `String`.
  **/
  public static function formatError<T>(result : ParseResult<T>, stream : String) : String {
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
    Create successfull `ParseResult` with specified `index` and `value`.
  **/
  inline private static function makeSuccess<A>(index : Int, value : A) : ParseResult<A> {
    return {
      status: true,
      index: index,
      value: value,
      furthest: -1,
      expected: []
    };
  }

  /**
    Create failed `ParseResult` with specified `index` and `expected` input.
  **/
  inline private static function makeFailure<A>(index : Int, expected : String) : ParseResult<A> {
    return {
      status: false,
      index: -1,
      value: null,
      furthest: index,
      expected: [expected]
    };
  }

  /**
    Merge `result` and `last` into single `ParseResult`.
  **/
  private static function mergeReplies<A, B>(result : ParseResult<A>, ?last : ParseResult<B>) : ParseResult<A> {
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
