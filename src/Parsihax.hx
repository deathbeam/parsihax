import haxe.ds.Option;
import haxe.ds.Vector;
import com.mindrocks.monads.Monad;
using Parsihax;

/**
  0-based offset and 1-based line and column properties indicating current position in stream.
**/
typedef Index = {
  /**
    Current offset from start of the stream
  **/
  var offset : Int;

  /**
    Current line in stream
  **/
  var line : Int;

  /**
    Current column in stream
  **/
  var column : Int;
}

/**
  Structure yielded from `Parsihax.mark`, what contains original value yielded
  by parser and start, end `Index`
**/
typedef Mark<T> = {
  /**
    `Index` indicating start position of `value` in stream
  **/
  var start : Index;

  /**
    `Index` indicating end position of `value` in stream
  **/
  var end : Index;

  /**
    Original value yielded by `Parser`
  **/
  var value : T;
}

/**
  A structure with a boolean `status` flag, indicating whether the parse
  succeeded. If it succeeded, the `value` attribute will contain the yielded
  value. Otherwise, the `index` and `expected` attributes will contain the
  offset of the parse error, and a sorted, unique array of messages indicating
  what was expected.

  The error structure can be passed along with the original source to
  `Parsihax.formatError` to obtain a human-readable error string.
**/
typedef Result<T> = {
  /**
    Flag, indicating whether the parse succeeded
  **/
  @:optional var status : Bool;

  /**
    Offset of the parse error (in case of failed parse)
  **/
  @:optional var index : Int;

  /**
    Yielded value of `Parser` (in case of successfull parse)
  **/
  @:optional var value : T;

  /**
    Offset of last parse
  **/
  @:optional var furthest : Int;

  /**
    A sorted, unique array of messages indicating what was expected (in case of failed parse)
  **/
  @:optional var expected : Array<String>;
};

/**
  Parsing function created by chaining Parsihax combinators.
**/
typedef Function<A> = String -> ?Int -> Result<A>;

/**
  The Parser object is a wrapper for a parser function.
  Externally, you use one to parse a string by calling
    `var result = SomeParser.parse('Me Me Me! Parse Me!');`
**/
abstract Parser<T>(Vector<Function<T>>) {
  inline function new() this = new Vector(1);
  @:to inline function get_parse() : Function<T> return this[0];
  inline function set_parse(param : Function<T>) return this[0] = param;

  /**
    Getting `Parser.parse` from a parser (or explicitly casting it to
    `Function` returns parsing function `String -> ?Int -> Result<A>`
    (or just `Function`), that parses the string and returns `Result<A>`.

    Changing `Parser.parse` value changes parser behaviour, but still keeps it's
    reference, what is really usefull in recursive parsers.
  **/
  public var parse(get, set): Function<T>;

  /**
    Creates `Parser` from `Function`
  **/
  @:noUsing @:from static inline public function to<T>(v : Function<T>) : Parser<T> {
    var ret = new Parser();
    ret.parse = v;
    return ret;
  }
}

/**
  Defines grammar and encapsulates parsing logic. A `Parser` takes as input a
  `String` source and parses it when the `Parser.parse` method is called.
  A structure `Result` is returned.
**/
class Parsihax {
  /**
    Equivalent to `Parsihax.regexp(~/[a-z]/i)`
  **/
  inline public static function letter() : Parser<String> {
    return ~/[a-z]/i.regexp().desc('a letter');
  }

  /**
    Equivalent to `Parsihax.regexp(~/[a-z]* /i)`
  **/
  inline public static function letters() : Parser<String> {
    return ~/[a-z]*/i.regexp();
  }

  /**
    Equivalent to `Parsihax.regexp(~/[0-9]/)`
  **/
  inline public static function digit() : Parser<String> {
    return ~/[0-9]/.regexp().desc('a digit');
  }

  /**
    Equivalent to `Parsihax.regexp(~/[0-9]* /)`
  **/
  inline public static function digits() : Parser<String> {
    return ~/[0-9]*/.regexp();
  }

  /**
    Equivalent to `Parsihax.regexp(~/\s+/)`
  **/
  inline public static function whitespace() : Parser<String> {
    return ~/\s+/.regexp().desc('whitespace');
  }

  /**
    Equivalent to `Parsihax.regexp(~/\s* /)`
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
    A `Parser` that consumes no text and yields an object an `Index`,
    representing the current offset into the parse: it has a 0-based character
    offset property and 1-based line and column properties.

    ```haxe
    var parser : Parser<Array<Dynamic>> = Parsihax.seq([
      Parsihax.oneOf('Q\n').many(),
      Parsihax.string('B'),
      Parsihax.index()
    ]);
    
    parser.map(function(results) {
      var index = results[2];
      console.log(index.offset); // => 8
      console.log(index.line);   // => 3
      console.log(index.column); // => 5
      return results[1];
    }).parse('QQ\n\nQQQB');
    ```
  **/
  public static function index() : Parser<Index> {
    return function(stream : String, i : Int = 0) : Result<Index> {
      return makeSuccess(i, makeIndex(stream, i));
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
    yields that exact value. This combinator is faster than `Parsihax.string`
    in case of matching single character.
  **/
  public static function char(character : String) : Parser<String> {
    return function(ch) { return character == ch; }.test().desc("'"+character+"'");
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
    This is an alias for `Parser.regexp`
  **/
  inline public static function regex(re : EReg, group : Int = 0) : Parser<String> {
    return regexp(re, group);
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
    This is an alias for `Parser.succeed`. 
  **/
  inline public static function of<A>(value : A) : Parser<A> {
    return value.succeed();
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
        result = mergeReplies(parser.parse(stream, i), result);
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
    Parsihax.choice([
      Parsihax.string('ab'),
      Parsihax.string('a')
    ]).parse('ab');
    // => {status: true, value: 'ab'}

    Parsihax.choice([
      Parsihax.string('a'),
      Parsihax.string('ab')
    ]).parse('ab');
    // => {status: false, ...}
    ```

    In the second case, `Parsihax.choice` matches on the first parser, then
    there are extra characters left over (`'b'`), so `Parser` returns a failure. 
  **/
  public static function choice<A>(parsers : Array<Parser<A>>) : Parser<A> {
    if (parsers.length == 0) return fail('at least one choice');

    return function(stream : String, i : Int = 0) : Result<A> {
      var result : Result<A> = null;

      for (parser in parsers) {
        result = mergeReplies(parser.parse(stream, i), result);
        if (result.status) return result;
      }

      return result;
    };
  }

  /**
    Accepts two `Parser`s, and expects zero or more matches for content,
    separated by `separator`, yielding an array.

    ```haxe
    Parsihax.sepBy(
      Parsihax.oneOf('abc'),
      Parsihax.string('|')
    ).parse('a|b|c|c|c|a');
    // => {status: true, value: ['a', 'b', 'c', 'c', 'c', 'a']}

    Parsihax.sepBy(
      Parsihax.oneOf('XYZ'),
      Parsihax.string('-')
    ).parse('');
    // => {status: true, value: []}
    ```
  **/
  inline public static function sepBy<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    return parser.sepBy1(separator).or([].of());
  }

  /**
    This is the same as `Parser.sepBy`, but matches the content parser at least
    once.
  **/
  public static function sepBy1<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    var pairs = separator.then(parser).many();

    return parser.bind(function(r) {
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
    static var Value = Parsihax.lazy(function() {
      return Parsihax.choice([
        Parsihax.string('x'),
        Parsihax.string('(')
          .then(Value)
          .skip(Parsihax.string(')'))
      ]);
    });

    // ...
    Value.parse('X');     // => {status: true, value: 'X'}
    Value.parse('(X)');   // => {status: true, value: 'X'}
    Value.parse('((X))'); // => {status: true, value: 'X'}
    ```
  **/
  public static function lazy<A>(fun : Void -> Parser<A>) : Parser<A> {
    var parser : Parser<A> = null;
    
    return parser = function(stream : String, i : Int = 0) : Result<A> {
      return (parser.parse = fun().parse)(stream, i);
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
    Returns a `Parser` that yield a single character if it passes the `predicate`
    function `String -> Bool`.

    ```haxe
    var SameUpperLower = Parsihax.test(function(c) {
      return c.toUpperCase() == c.toLowerCase();
    });

    SameUpperLower.parse('a'); // => {status: false, ...}
    SameUpperLower.parse('-'); // => {status: true, ...}
    SameUpperLower.parse(':'); // => {status: true, ...}
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
      Parsihax.string('%')
        .then(Parsihax.any())
        .bind(function(start) {
          var end = [
            '[' => ']',
            '(' => ')',
            '{' => '}',
            '<'=> '>'
          ][start];
          end = end != null ? end : start;

          return Parsihax.takeWhile(function(c) {
            return c != end;
          }).skip(Parsihax.string(end));
        });

    CustomString.parse('%:a string:'); // => {status: true, value: 'a string'}
    CustomString.parse('%[a string]'); // => {status: true, value: 'a string'}
    CustomString.parse('%{a string}'); // => {status: true, value: 'a string'}
    CustomString.parse('%(a string)'); // => {status: true, value: 'a string'}
    CustomString.parse('%<a string>'); // => {status: true, value: 'a string'}
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
      Parsihax.string('+')
        .or(Parsihax.of('-'))
        .or(Parsihax.of(''));

    numberPrefix.parse('+'); // => {status: true, value: '+'}
    numberPrefix.parse('-'); // => {status: true, value: '-'}
    numberPrefix.parse('');  // => {status: true, value: ''}
    ```
  **/
  public static function or<A>(parser: Parser<A>, alternative : Parser<A>) : Parser<A> {
    return [parser, alternative].choice();
  }

  /**
    Returns a new `Parser` which tries `parser`, and on success calls the function
    `fun : A -> Parser<B>` with the result of the parse, which is expected to
    return another parser, which will be tried next. This allows you to
    dynamically decide how to continue the parse, which is impossible with the
    other combinators.

    ```haxe
    var CustomString =
      Parsihax.string('%')
        .then(Parsihax.any())
        .bind(function(start) {
          var end = [
            '[' => ']',
            '(' => ')',
            '{' => '}',
            '<'=> '>'
          ][start];
          end = end != null ? end : start;

          return Parsihax.takeWhile(function(c) {
            return c != end;
          }).skip(Parsihax.string(end));
        });

    CustomString.parse('%:a string:'); // => {status: true, value: 'a string'}
    CustomString.parse('%[a string]'); // => {status: true, value: 'a string'}
    CustomString.parse('%{a string}'); // => {status: true, value: 'a string'}
    CustomString.parse('%(a string)'); // => {status: true, value: 'a string'}
    CustomString.parse('%<a string>'); // => {status: true, value: 'a string'}
    ```
  **/
  public static function bind<A, B>(parser: Parser<A>, fun : A -> Parser<B>) : Parser<B> {
    return function(stream : String, i : Int = 0) : Result<B> {
      var result = parser.parse(stream, i);
      if (!result.status) return cast(result);
      var nextParser = fun(result.value);
      return mergeReplies(nextParser.parse(stream, result.index), result);
    };
  }

  /**
    Expects `next` to follow `parser`, and yields the result of `next`.

    ```haxe
    var parserA = p1.then(p2); // is equivalent to...
    var parserB = Parsihax.seq([p1, p2]).map(function(results) return results[1]);
    ```
  **/
  public static function then<A, B>(parser: Parser<A>, next : Parser<B>) : Parser<B> {
    return parser.bind(function(result) return next);
  }

  /**
    Transforms the output of `parser` with the given function `fun : A -> B`.

    ```haxe
    var pNum = Parsihax.regexp(~/[0-9]+/).map(Std.parseInt);

    pNum.parse('9');   // => {status: true, value: 9}
    pNum.parse('123'); // => {status: true, value: 123}
    pNum.parse('3.1'); // => {status: true, value: 3.1}
    ```
  **/
  public static function map<A, B>(parser: Parser<A>, fun : A -> B) : Parser<B> {
    return function(stream : String, i : Int = 0) : Result<B> {
      var result = parser.parse(stream, i);
      if (!result.status) return cast(result);
      return mergeReplies(makeSuccess(result.index, fun(result.value)), result);
    };
  }

  /**
    Returns a new `Parser` with the same behavior, but which yields `value`.
    Equivalent to `Parsihax.map(parser, function(x) return x)`.
  **/
  public static function result<A, B>(parser: Parser<A>, value : B) : Parser<B> {
    return parser.map(function(_) return value);
  }

  /**
    Expects `next` after `parser`, but yields the value of `parser`.

    ```haxe
    var parserA = p1.skip(p2); // is equivalent to...
    var parserB = Parsihax.seq([p1, p2]).map(function(results) return results[0]);
    ```
  **/
  public static function skip<A, B>(parser: Parser<A>, next : Parser<B>) : Parser<A> {
    return parser.bind(function(result) return next.result(result));
  };

  /**
    Expects `Parser` zero or more times, and yields an array of the results.
  **/
  public static function many<A>(parser: Parser<A>) : Parser<Array<A>> {
    return function(stream : String, i : Int = 0) : Result<Array<A>> {
      var accum : Array<A> = [];
      var result = null;

      while (true) {
        result = mergeReplies(parser.parse(stream, i), result);

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
        result = parser.parse(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else return cast(prevResult);
      }

      for (times in 0...max) {
        result = parser.parse(stream, i);
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
    A `Parser` for an operand followed by zero or more operands separated by
    right-associative `operator`s.
  **/
  inline public static function chainr<A>(parser : Parser<A>, operator : Parser<A->A->A>) : Parser<A> {
    return chainr1(parser, operator).or(parser);
  }

  /**
    A `Parser` for an operand followed by one or more operands separated by
    right-associative `operator`s.
  **/
  public static function chainr1<A>(parser : Parser<A>, operator : Parser<A->A->A>) : Parser<A> {
    return scanr1(parser, operator);
  }

  private static function scanr1<A>(parser : Parser<A>, operator : Parser<A->A->A>) : Parser<A> {
    return bind(parser, function(x) return restr1(parser, operator, x));
  }

  private static function restr1<A>(parser : Parser<A>, operator : Parser<A->A->A>, x : A) : Parser<A> {
    return bind(operator, function(f) {
      return bind(scanr1(parser, operator), function(y) {
        return f(x, y).of();
      });
    }).or(x.of());
  }

  /**
    A `Parser` for an operand followed by zero or more operands separated by
    `operator`s. This parser can for example be used to eliminate left
    recursion which typically occurs in expression grammars.
  **/
  public static function chainl<A>(parser : Parser<A>, operator : Parser<A->A->A>) : Parser<A> {
    return chainl(parser, operator).or(parser);
  }

  /**
    A `Parser` for an operand followed by one or more operands separated by
    `operator`s. This parser can for example be used to eliminate left
    recursion which typically occurs in expression grammars.
  **/
  public static function chainl1<A>(parser : Parser<A>, operator : Parser<A->A->A>) : Parser<A> {
    return bind(parser, function(x) return restl1(parser, operator, x));
  }

  private static function restl1<A>(parser : Parser<A>, operator : Parser<A->A->A>, x : A) : Parser<A> {
    return bind(operator, function(f) {
      return bind(parser, function(y) {
        return restl1(parser, operator, f(x, y));
      });
    }).or(x.of());
  }

  /**
    Yields a structure `Mark` with start, value, and end keys, where value is the
    original value yielded by the `parser`, and start and end are are objects
    with a 0-based offset and 1-based line and column properties that represent
    the position in the stream that contained the parsed text.
  **/
  public static function mark<A>(parser: Parser<A>) : Parser<Mark<A>> {
    return index().bind(function(start) {
      return parser.bind(function(value) {
        return index().map(function(end) {
          return {
            start: start,
            value: value,
            end: end
          };
        });
      });
    });
  }

  /**
    Returns a new `Parser` whose failure message is description. For example,
    `string('x').desc('the letter x')` will indicate that 'the letter x' was
    expected.
  **/
  public static function desc<A>(parser: Parser<A>, expected : String) : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      var reply = parser.parse(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    };
  }

  /**
    Returns a new failed `Parser` with 'empty' message
  **/
  public static function empty<A>() : Parser<A> {
    return fail('empty');
  }

  /**
    Makes `Parser` optional, and returns `None` in the case that the
    parser does not accept the current input. Otherwise, if `Parser` would have
    parsed and returned an `A`, option` will parse and return a
    `Some(A)`.
  **/
  public static function option<A>(parser: Parser<A>) : Parser<Option<A>> {
    return parser.map(function(r) {
      return Some(r);
    }).or(of(None));
  }

  /**
    You can add a primitive parser (similar to the included ones) by using this.
    This is an example of how to create a parser that matches any character
    except the one provided:

    ```haxe
    function notChar(char) {
      return Parsihax.custom(function(success, failure) {
        return function(stream, i) {
          if (stream.charAt(i) != char && i <= stream.length) {
            return success(i + 1, stream.charAt(i));
          }
          return failure(i, 'anything different than "$char"');
        };
      });
    }
    ```

    This parser can then be used and composed the same way all the existing ones
    are used and composed, for example:

    ```haxe
    var parser : Parser<Array<Dynamic>> =
      Parsihax.seq([
        Parsihax.string('a'),
        notChar('b').times(5)
      ]);

    parser.parse('accccc');
    //=> {status: true, value: ['a', ['c', 'c', 'c', 'c', 'c']]}
    ```
  **/
  public static function custom<A>(parsingFunction
      : (Int -> A -> Result<A>)
      -> (Int -> String -> Result<A>)
      -> (Function<A>)) : Parser<A> {
    return parsingFunction(makeSuccess, makeFailure);
  }

  /**
    Obtain a human-readable error `String`.
  **/
  public static function formatError<T>(result : Result<T>, stream : String) : String {
    var sexpected = result.expected.length == 1
      ? result.expected[0]
      : 'one of ' + result.expected.join(', ');
    
    var index = makeIndex(stream, result.furthest);
    var got = '';
    var i = index.offset;

    if (i == stream.length) {
      got = ', got the end of the stream';
    } else {
      var prefix = (i > 0 ? "'..." : "'");
      var suffix = (stream.length - i > 12 ? "...'" : "'");

      got = ' at line ' + index.line + ' column ' + index.column
        +  ', got ' + prefix + stream.substring(i, i + 12) + suffix;
    }

    return 'expected ' + sexpected + got;
  }

  /**
    `Monad` compatibility. Function for initializing the monad sugar. 
  **/
  macro public static function monad(body : haxe.macro.Expr) {
    return Monad._dO("Parsihax", body, haxe.macro.Context);
  }

  /**
    `Monad` compatibility. This is an alias for `Parsihax.succeed`. 
  **/
  inline public static function ret<T>(value : T) : Parser<T> {
    return value.succeed();
  }

  /**
    `Monad` compatibility. This is an alias for `Parsihax.bind`. 
  **/
  inline public static function flatMap<T,U>(parser : Parser<T> , next : T -> Parser<U>) : Parser<U> {
    return parser.bind(next);
  }

  inline private static function makeSuccess<A>(index : Int, value : A) : Result<A> {
    return {
      status: true,
      index: index,
      value: value,
      furthest: -1,
      expected: []
    };
  }

  inline private static function makeFailure<A>(index : Int, expected : String) : Result<A> {
    return {
      status: false,
      index: -1,
      value: null,
      furthest: index,
      expected: [expected]
    };
  }

  private static function makeIndex(stream : String, i : Int) : Index {
    var lines = stream.substring(0, i).split("\n");
    var lineWeAreUpTo = lines.length;
    var columnWeAreUpTo = lines[lines.length - 1].length + 1;

    return {
      offset: i,
      line: lineWeAreUpTo,
      column: columnWeAreUpTo
    };
  };

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
