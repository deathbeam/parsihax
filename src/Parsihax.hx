import haxe.ds.Option;
import com.mindrocks.monads.Monad;
using Parsihax;

typedef Index = {
  var offset: Int;
  var line: Int;
  var column: Int;
}

typedef Mark<T> = {
  var start: Index;
  var end: Index;
  var value: T;
}

typedef Result<T> = {
  @:optional var status : Bool;
  @:optional var index : Int;
  @:optional var value: T;
  @:optional var furthest: Int;
  @:optional var expected : Array<String>;
};

typedef Function<A> = String -> ?Int -> Result<A>;

/**
  The Parser object is a wrapper for a parser function.
  Externally, you use one to parse a string by calling
    var result = SomeParser.parse('Me Me Me! Parse Me!');
**/
abstract Parser<T>(haxe.ds.Vector<Function<T>>) {
  inline function new() this = new haxe.ds.Vector(1);
  @:to inline function get_parse() : Function<T> return this[0];
  inline function set_parse(param : Function<T>) return this[0] = param;

  /**
    Getting `parse` from a parser (or explicitly casting it to `Parsihax.Function` returns parsing function
    `String -> ?Int -> Result<A>` (or just `Function`), that parses the string and returns an object with a boolean
    `status` flag, indicating whether the parse succeeded. If it succeeded, the `value` attribute will contain the
    yielded value. Otherwise, the `index` and `expected` attributes will contain the offset of the parse error, and
    a sorted, unique array of messages indicating what was expected.

    The error object can be passed along with the original source to `Parsihax.formatError(error, source)` to obtain
    a human-readable error string.

    Changing `parse` value changes parser behaviour, but still keeps it's reference, what is really usefull in recursive parsers.
  **/
  public var parse(get, set): Function<T>;

  /**
    Creates `Parser` from `Function`
  **/
  @:noUsing @:from static inline public function to<T>(v: Function<T>): Parser<T> {
    var ret = new Parser();
    ret.parse = v;
    return ret;
  }
}

/**
  Defines grammar and encapsulates parsing logic. A `Parser` takes as input a
  `String` source and parses it when the `parse` method is called.
  An enum `Result` is returned, which can be `Success` or `Failure`
**/
class Parsihax {
  /**
    Equivalent to regexp [a-z] /i
  **/
  inline public static function letter() : Parser<String> {
    return ~/[a-z]/i.regexp().desc('a letter');
  }

  /**
    Equivalent to regexp [a-z]* /i
  **/
  inline public static function letters() : Parser<String> {
    return ~/[a-z]*/i.regexp();
  }

  /**
    Equivalent to regex [0-9]
  **/
  inline public static function digit() : Parser<String> {
    return ~/[0-9]/.regexp().desc('a digit');
  }

  /**
    Equivalent to regexp [0-9]*
  **/
  inline public static function digits() : Parser<String> {
    return ~/[0-9]*/.regexp();
  }

  /**
    Equivalent to regexp \s+
  **/
  inline public static function whitespace() : Parser<String> {
    return ~/\s+/.regexp().desc('whitespace');
  }

  /**
    Equivalent to regexp \s*
  **/
  inline public static function optWhitespace() : Parser<String> {
    return ~/\s*/.regexp();
  }

  /**
    A parser that consumes and yields the next character of the stream.
  **/
  public static function any() : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      return i >= stream.length
        ? makeFailure(i, 'any character')
        : makeSuccess(i+1, stream.charAt(i));
    };
  }

  /**
    A parser that consumes and yields the entire remainder of the stream.
  **/
  public static function all() : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      return makeSuccess(stream.length, stream.substring(i));
    };
  }

  /**
    A parser that expects to be at the end of the stream (zero characters left).
  **/
  public static function eof<A>() : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      return i < stream.length
        ? makeFailure(i, 'EOF')
        : makeSuccess(i, null);
    };
  }

  /**
    A parser that consumes no text and yields an object an object representing the current offset into the parse:
    it has a 0-based character offset property and 1-based line and column properties.
  **/
  public static function index() : Parser<Index> {
    return function(stream : String, i : Int = 0) : Result<Index> {
      return makeSuccess(i, makeIndex(stream, i));
    };
  }

  /**
    Returns a parser that looks for string and yields that exact value.
  **/
  public static function string(str : String) : Parser<String> {
    var len = str.length;
    var expected = "'"+str+"'";

    return function(stream : String, i : Int = 0) : Result<String> {
      var head = stream.substring(i, i + len);

      if (head == str) {
        return makeSuccess(i+len, head);
      } else {
        return makeFailure(i, expected);
      }
    };
  }

  /**
    Returns a parser that looks for exactly one `character` and yields that exact value.
    This combinator is faster than `string` in case of matching single character.
  **/
  public static function char(character : String) : Parser<String> {
    return function(ch) { return character == ch; }.test().desc("'"+character+"'");
  }

  /**
    Returns a parser that looks for exactly one character from string, and yields that character.
  **/
  public static function oneOf(str : String) : Parser<String> {
    return function(ch) { return str.indexOf(ch) >= 0; }.test();
  }

  /**
    Returns a parser that looks for exactly one character NOT from string, and yields that character.
  **/
  public static function noneOf(str : String) : Parser<String> {
    return function(ch) { return str.indexOf(ch) < 0; }.test();
  }

  /**
    Returns a parser that looks for a match to the regexp and yields the given match group (defaulting to the entire match).
    The regexp will always match starting at the current parse location. The regexp may only use the following flags: imu.
    Any other flag will result in an error being thrown.
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
    This is an alias for Parser.regexp
  **/
  inline public static function regex(re : EReg, group : Int = 0) : Parser<String> {
    return regexp(re, group);
  }

  /**
    Returns a parser that doesn't consume any of the string, and yields result. 
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
    Accepts array of parsers and returns a new parser that expects them to match in order, yielding an array of all their results.
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
    Accepts array of parsers, yielding the value of the first one that succeeds, backtracking in between.
    This means that the order of parsers matters. If two parsers match the same prefix, the longer of the two must come first. 
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
    Accepts two parsers, and expects zero or more matches for content, separated by separator, yielding an array.
  **/
  inline public static function sepBy<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    return parser.sepBy1(separator).or([].of());
  }

  /**
    This is the same as Parser.sepBy, but matches the content parser at least once.
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
    Accepts a function that returns a parser, which is evaluated the first time the parser is used.
    This is useful for referencing parsers that haven't yet been defined, and for implementing recursive parsers.
  **/
  public static function lazy<A>(f : Void -> Parser<A>) : Parser<A> {
    var parser : Parser<A> = null;
    
    return parser = function(stream : String, i : Int = 0) : Result<A> {
      return (parser.parse = f().parse)(stream, i);
    };
  }

  /**
    Returns a failing parser with the given message.
  **/
  public static function fail<A>(expected : String) : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      return makeFailure(i, expected);
    }
  }

  /**
    Returns a parser that yield a single character if it passes the predicate function.
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
    Returns a parser yield a string containing all the next characters that pass the predicate.
  **/
  public static function takeWhile(predicate : String -> Bool) : Parser<String> {
    return function(stream : String, i : Int = 0) : Result<String> {
      var j = i;
      while (j < stream.length && predicate(stream.charAt(j))) j += 1;
      return makeSuccess(j, stream.substring(i, j));
    };
  }

  /**
    Returns a new parser which tries `parser`, and if it fails uses `alternative`.
  **/
  public static function or<A>(parser: Parser<A>, alternative : Parser<A>) : Parser<A> {
    return [parser, alternative].choice();
  }

  /**
    Returns a new parser which tries `parser`, and on success calls the function `f` with the result
    of the parse, which is expected to return another parser, which will be tried next. This allows you to
    dynamically decide how to continue the parse, which is impossible with the other combinators.
  **/
  public static function bind<A, B>(parser: Parser<A>, f : A -> Parser<B>) : Parser<B> {
    return function(stream : String, i : Int = 0) : Result<B> {
      var result = parser.parse(stream, i);
      if (!result.status) return cast(result);
      var nextParser = f(result.value);
      return mergeReplies(nextParser.parse(stream, result.index), result);
    };
  }

  /**
    Expects `next` to follow `parser`, and yields the result of `next`.
  **/
  public static function then<A, B>(parser: Parser<A>, next : Parser<B>) : Parser<B> {
    return parser.bind(function(result) return next);
  }

  /**
    Transforms the output of `parser` with the given function `f`.
  **/
  public static function map<A, B>(parser: Parser<A>, f : A -> B) : Parser<B> {
    return function(stream : String, i : Int = 0) : Result<B> {
      var result = parser.parse(stream, i);
      if (!result.status) return cast(result);
      return mergeReplies(makeSuccess(result.index, f(result.value)), result);
    };
  }

  /**
    Returns a new parser with the same behavior, but which yields value. Equivalent to parser.map(function(x) return x).
  **/
  public static function result<A, B>(parser: Parser<A>, res : B) : Parser<B> {
    return parser.map(function(_) return res);
  }

  /**
    Expects `next` after `parser`, but yields the value of `parser`.
  **/
  public static function skip<A, B>(parser: Parser<A>, next : Parser<B>) : Parser<A> {
    return parser.bind(function(result) return next.result(result));
  };

  /**
    Expects `parser` zero or more times, and yields an array of the results.
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
    Expects `parser` one or more times, and yields an array of the results.
  **/
  inline public static function many1<A>(parser: Parser<A>) : Parser<Array<A>> {
    return parser.atLeast(1);
  }

  /**
    Expects `parser` between `min` and `max` times (or exactly `min` times, when `max` is omitted),
    and yields an array of the results.
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
    Expects `parser` at most `n` times. Yields an array of the results.
  **/
  inline public static function atMost<A>(parser: Parser<A>, n : Int) : Parser<Array<A>> {
    return parser.times(0, n);
  }

  /**
    Expects `parser` at least `n` times. Yields an array of the results.
  **/
  public static function atLeast<A>(parser: Parser<A>, n : Int) : Parser<Array<A>> {
    return [parser.times(n), parser.many()].seq().map(function(results) {
      return results[0].concat(results[1]);
    });
  }

  /**
    A parser for an operand followed by zero or more operands (`p`) separated by right-associative operators (`op`).
  **/
  inline public static function chainr<A>(p : Parser<A>, op : Parser<A->A->A>) : Parser<A> {
    return chainr1(p, op).or(p);
  }

  /**
    A parser for an operand followed by one or more operands (`p`) separated by right-associative operators (`op`).
  **/
  public static function chainr1<A>(p : Parser<A>, op : Parser<A->A->A>) : Parser<A> {
    return scanr1(p, op);
  }

  private static function scanr1<A>(p : Parser<A>, op : Parser<A->A->A>) : Parser<A> {
    return bind(p, function(x) return restr1(p, op, x));
  }

  private static function restr1<A>(p : Parser<A>, op : Parser<A->A->A>, x : A) : Parser<A> {
    return bind(op, function(f) {
      return bind(scanr1(p, op), function(y) {
        return f(x, y).of();
      });
    }).or(x.of());
  }

  /**
    A parser for an operand followed by zero or more operands (`p`) separated by operators (`op`).
    This parser can for example be used to eliminate left recursion which typically occurs in expression grammars.
  **/
  public static function chainl<A>(p : Parser<A>, op : Parser<A->A->A>) : Parser<A> {
    return chainl(p, op).or(p);
  }

  /**
    A parser for an operand followed by one or more operands (`p`) separated by operators (`op`).
    This parser can for example be used to eliminate left recursion which typically occurs in expression grammars.
  **/
  public static function chainl1<A>(p : Parser<A>, op : Parser<A->A->A>) : Parser<A> {
    return bind(p, function(x) return restl1(p, op, x));
  }

  private static function restl1<A>(p : Parser<A>, op : Parser<A->A->A>, x : A) : Parser<A> {
    return bind(op, function(f) {
      return bind(p, function(y) {
        return restl1(p, op, f(x, y));
      });
    }).or(x.of());
  }

  /**
    Yields an object with start, value, and end keys, where value is the original value yielded by the `parser`,
    and start and end are are objects with a 0-based offset and 1-based line and column properties that represent
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
    Returns a new parser whose failure message is description. For example, string('x').desc('the letter x')
    will indicate that 'the letter x' was expected.
  **/
  public static function desc<A>(parser: Parser<A>, expected : String) : Parser<A> {
    return function(stream : String, i : Int = 0) : Result<A> {
      var reply = parser.parse(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    };
  }

  /**
    Returns a new failed parser with 'empty' message
  **/
  public static function empty<A>() : Parser<A> {
    return fail('empty');
  }

  /**
    Makes `parser` optional, and returns `None` in the case that
    the parser does not accept the current input. Otherwise, if
    `parser` would have parsed and returned an `A`, option` will
    parse and return a `Some(A)`.
  **/
  public static function option<A>(parser: Parser<A>) : Parser<Option<A>> {
    return parser.map(function(r) {
      return Some(r);
    }).or(of(None));
  }

  /**
    You can add a primitive parser (similar to the included ones) by using this.
  **/
  public static function custom<A>(parsingFunction
      : (Int -> A -> Result<A>)
      -> (Int -> String -> Result<A>)
      -> (Function<A>)) : Parser<A> {
    return parsingFunction(makeSuccess, makeFailure);
  }

  /**
    Obtain a human-readable error string.
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
    Monax compatibility.
    Function for initializing the monad sugar. 
  **/
  macro public static function monad(body : haxe.macro.Expr) {
    return Monad._dO("Parsihax", body, haxe.macro.Context);
  }

  /**
    Monax compatibility.
    This is an alias for `Parsihax.succeed`. 
  **/
  inline public static function ret<T>(v : T) : Parser<T> {
    return v.succeed();
  }

  /**
    Monax compatibility.
    This is an alias for `Parsihax.chain`. 
  **/
  inline public static function flatMap<T,U>(p1 : Parser<T> , fp2 : T -> Parser<U>) : Parser<U> {
    return p1.bind(fp2);
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