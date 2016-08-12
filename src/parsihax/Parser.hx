package parsihax;

import haxe.ds.Option;

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

typedef Data<T> = {
  @:optional var status : Bool;
  @:optional var index : Int;
  @:optional var value: T;
  @:optional var furthest: Int;
  @:optional var expected : Array<String>;
};

enum Result<T> {
  Success(value : T);
  Failure(index : Index, expected : Array<String>);
}

/**
 * An atomic mutable reference to {@link Parser} used in recursive grammars.
 */
class Ref<A> extends Parser<A> {
  private function new(action : String -> Int -> Data<A>) {
    super(action);
  }

  public function set(parser : Parser<A>) : Ref<A> {
    this.action = parser.action;
    return this;
  }
}

/**
 * Defines grammar and encapsulates parsing logic. A {@link Parser} takes as input a
 * {@link String} source and parses it when the {@link #parse(String)} method is called.
 * An enum {@link Result} is return, which can be Success(value : Dynamic) or
 * Failure(index : Index, expected : Array<String>)
 */
class Parser<A> {
  /**
   * Equivalent to regexp [a-z] /i
   */
  public static function letter() : Parser<String> {
    return regexp(~/[a-z]/i).desc('a letter');
  }

  /**
   * Equivalent to regexp [a-z]* /i
   */
  public static function letters() : Parser<String> {
    return regexp(~/[a-z]*/i);
  }

  /**
   * Equivalent to regex [0-9]
   */
  public static function digit() : Parser<String> {
    return regexp(~/[0-9]/).desc('a digit');
  }

  /**
   * Equivalent to regexp [0-9]*
   */
  public static function digits() : Parser<String> {
    return regexp(~/[0-9]*/);
  }

  /**
   * Equivalent to regexp \s+
   */
  public static function whitespace() : Parser<String> {
    return regexp(~/\s+/).desc('whitespace');
  }

  /**
   * Equivalent to regexp \s*
   */
  public static function optWhitespace() : Parser<String> {
    return regexp(~/\s*/);
  }

  /**
   * A parser that consumes and yields the next character of the stream.
   */
  public static function any() : Parser<String> {
    return new Parser(function(stream, i) {
      return i >= stream.length
        ? makeFailure(i, 'any character')
        : makeSuccess(i+1, stream.charAt(i));
    });
  }

  /**
   * A parser that consumes and yields the entire remainder of the stream.
   */
  public static function all() : Parser<String> {
    return new Parser(function(stream, i) {
      return makeSuccess(stream.length, stream.substring(i));
    });
  }

  /**
   * A parser that expects to be at the end of the stream (zero characters left).
   */
  public static function eof<A>() : Parser<A> {
    return new Parser(function(stream, i) {
      return i < stream.length
        ? makeFailure(i, 'EOF')
        : makeSuccess(i, null);
    });
  }

  /**
   * A parser that consumes no text and yields an object an object representing the current offset into the parse:
   * it has a 0-based character offset property and 1-based line and column properties.
   */
  public static function index() : Parser<Index> {
    return new Parser(function(stream, i) {
      return makeSuccess(i, makeIndex(stream, i));
    });
  }

  /**
   * Create parser reference, usefull for recursive parsers. If parsing is tried on this reference
   * directly, without concating it, it returns failed parser.
   */
  public static function ref<A>() : Ref<A> {
    return new Ref(fail('actual parser, and not reference').action);
  }

  /**
   * Returns a parser that looks for string and yields that exact value.
   */
  public static function string(str : String) : Parser<String> {
    var len = str.length;
    var expected = "'"+str+"'";

    return new Parser(function(stream, i) {
      var head = stream.substring(i, i + len);

      if (head == str) {
        return makeSuccess(i+len, head);
      } else {
        return makeFailure(i, expected);
      }
    });
  }

  /**
   * Returns a parser that looks for exactly one character from string, and yields that character.
   */
  public static function oneOf(str : String) : Parser<String> {
    return test(function(ch) {
      return str.indexOf(ch) >= 0;
    });
  }

  /**
   * Returns a parser that looks for exactly one character NOT from string, and yields that character.
   */
  public static function noneOf(str : String) : Parser<String> {
    return test(function(ch) {
      return str.indexOf(ch) < 0;
    });
  }

  /**
   * Returns a parser that looks for a match to the regexp and yields the given match group (defaulting to the entire match).
   * The regexp will always match starting at the current parse location. The regexp may only use the following flags: imu.
   * Any other flag will result in an error being thrown.
   */
  public static function regexp(re : EReg, group : Int = 0) : Parser<String> {
    var expected = Std.string(re);
    
    return new Parser(function(stream, i) {
      var match = re.match(stream.substring(i));

      if (match) {
        var groupMatch = re.matched(group);
        var pos = re.matchedPos();
        if (groupMatch != null && pos.pos == 0) {
          return makeSuccess(i + pos.len, groupMatch);
        }
      }

      return makeFailure(i, expected);
    });
  }

  /**
   * This is an alias for Parser.regexp
   */
  public static function regex(re : EReg, group : Int = 0) : Parser<String> {
    return regexp(re, group);
  }

  /**
   * Returns a parser that doesn't consume any of the string, and yields result. 
   */
  public static function succeed<A>(value : A) : Parser<A> {
    return new Parser(function(stream, i) {
      return makeSuccess(i, value);
    });
  }

  /**
   * This is an alias for Parser.succeed(result). 
   */
  public static function of<A>(value : A) : Parser<A> {
    return succeed(value);
  }

  /**
   * Accepts any number of parsers and returns a new parser that expects them to match in order, yielding an array of all their results.
   */
  public static function seq<A>(parsers : Array<Parser<A>>) : Parser<Array<A>> {
    var numParsers = parsers.length;

    return new Parser(function(stream, i) {
      var result : Data<A> = null;
      var accum : Array<A> = [];

      for (parser in parsers) {
        result = mergeReplies(parser.action(stream, i), result);
        if (!result.status) return cast(result);
        accum.push(result.value);
        i = result.index;
      }

      return mergeReplies(makeSuccess(i, accum), result);
    });
  }

  /**
   * Matches all parsers sequentially, and passes their results as the arguments to a function. Similar as calling Parser.seq
   * and then .map.
   */
  public static function seqMap<A, B>(parsers : Array<Parser<A>>, mapper : Array<A> -> B) : Parser<B> {
    return seq(parsers).map(function(results) {
      return mapper(results);
    });
  }

  /**
   * Accepts any number of parsers, yielding the value of the first one that succeeds, backtracking in between.
   * This means that the order of parsers matters. If two parsers match the same prefix, the longer of the two must come first. 
   */
  public static function alt<A>(parsers : Array<Parser<A>>) : Parser<A> {
    var numParsers = parsers.length;
    if (numParsers == 0) return fail('zero alternates');

    return new Parser(function(stream, i) {
      var result = null;

      for (parser in parsers) {
        result = mergeReplies(parser.action(stream, i), result);
        if (result.status) return result;
      }

      return result;
    });
  }

  /**
   * Accepts two parsers, and expects zero or more matches for content, separated by separator, yielding an array.
   */
  public static function sepBy<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    return sepBy1(parser, separator).or(of([]));
  }

  /**
   * This is the same as Parser.sepBy, but matches the content parser at least once.
   */
  public static function sepBy1<A, B>(parser : Parser<A>, separator : Parser<B>) : Parser<Array<A>> {
    var pairs = separator.then(parser).many();

    return parser.chain(function(r) {
      return pairs.map(function(rs) {
        return [r].concat(rs);
      });
    });
  }

  /**
   * Accepts a function that returns a parser, which is evaluated the first time the parser is used.
   * This is useful for referencing parsers that haven't yet been defined, and for implementing recursive parsers.
   */
  public static function lazy<A>(f : Void -> Parser<A>, ?desc : String) : Parser<A> {
    var parser : Parser<A> = null;
    
    parser = new Parser(function(stream, i) {
      parser.action = f().action;
      return parser.action(stream, i);
    });

    if (desc != null) parser = parser.desc(desc);
    return parser;
  }

  /**
   * Returns a failing parser with the given message.
   */
  public static function fail<A>(expected : String) : Parser<A> {
    return new Parser(function(stream, i) {
      return makeFailure(i, expected);
    });
  }

  /**
   * Returns a parser that yield a single character if it passes the predicate function.
   */
  public static function test(predicate : String -> Bool) : Parser<String> {
    return new Parser(function(stream, i) {
      var char = stream.charAt(i);

      return i < stream.length && predicate(char)
        ? makeSuccess(i+1, char)
        : makeFailure(i, 'a character matching '+predicate);
    });
  }

  /**
   * Returns a parser yield a string containing all the next characters that pass the predicate.
   */
  public static function takeWhile(predicate : String -> Bool) : Parser<String> {
    return new Parser(function(stream, i) {
      var j = i;
      while (j < stream.length && predicate(stream.charAt(j))) j += 1;
      return makeSuccess(j, stream.substring(i, j));
    });
  }

  /**
   * You can add a primitive parser (similar to the included ones) by using Parser.custom.
   */
  public static function custom<A>(parsingFunction
      : (Int -> A -> Data<A>)
      -> (Int -> String -> Data<A>)
      -> (String -> Int -> Data<A>)) : Parser<A> {
    return new Parser(parsingFunction(makeSuccess, makeFailure));
  }

  /**
   * Obtain a human-readable error string.
   */
  public static function formatError(stream : String, index : Index, expected : Array<String>) : String {
    var sexpected = expected.length == 1
      ? expected[0]
      : 'one of ' + expected.join(', ');
    
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
   * Calling .parse(string) on a parser parses the string and returns an object with a boolean status flag,
   * indicating whether the parse succeeded. If it succeeded, the value attribute will contain the yielded value.
   * Otherwise, the index and expected attributes will contain the index of the parse error
   * (with offset, line and column properties), and a sorted, unique array of messages indicating what was expected.
   */
  public function parse(stream : String) : Result<A> {
    var result = this.skip(eof()).action(stream, 0);

    return result.status
      ? Success(result.value)
      : Failure(makeIndex(stream, result.furthest), result.expected);
  }

  /**
   * Returns a new parser which tries parser, and if it fails uses otherParser.
   */
  public function or(alternative : Parser<A>) : Parser<A> {
    return alt([this, alternative]);
  }

  /**
   * Returns a new parser which tries parser, and on success calls the function newParserFunc with the result
   * of the parse, which is expected to return another parser, which will be tried next. This allows you to
   * dynamically decide how to continue the parse, which is impossible with the other combinators.
   */
  public function chain<B>(f : A -> Parser<B>) : Parser<B> {
    return new Parser(function(stream, i) {
      var result = this.action(stream, i);
      if (!result.status) return cast(result);
      var nextParser = f(result.value);
      return mergeReplies(nextParser.action(stream, result.index), result);
    });
  }

  /**
   * Expects anotherParser to follow parser, and yields the result of anotherParser.
   */
  public function then<B>(next : Parser<B>) : Parser<B> {
    return chain(function(result) {
      return next;
    });
  }

  /**
   * Transforms the output of parser with the given function.
   */
  public function map<B>(fn : A -> B) : Parser<B> {
    return new Parser(function(stream, i) {
      var result = this.action(stream, i);
      if (!result.status) return cast(result);
      return mergeReplies(makeSuccess(result.index, fn(result.value)), result);
    });
  }

  /**
   * Returns a new parser with the same behavior, but which yields value. Equivalent to parser.map(function(x) { return x; }.bind(value)).
   */
  public function result<B>(res : B) : Parser<B> {
    return this.map(function(_) { return res; });
  }

  /**
   * Expects otherParser after parser, but yields the value of parser.
   */
  public function skip<B>(next : Parser<B>) : Parser<A> {
    return chain(function(result) {
      return next.result(result);
    });
  };

  /**
   * Expects parser zero or more times, and yields an array of the results.
   */
  public function many() : Parser<Array<A>> {
    return new Parser(function(stream, i) {
      var accum : Array<A> = [];
      var result = null;

      while (true) {
        result = mergeReplies(this.action(stream, i), result);

        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else {
          return mergeReplies(makeSuccess(i, accum), result);
        }
      }
    });
  }

  /**
   * Expects parser between min and max times (or exactly x times, when second argument is omitted),
   * and yields an array of the results.
   */
  public function times(min : Int, ?max : Int) : Parser<Array<A>> {
    if (max == null) max = min;

    return new Parser(function(stream, i) {
      var accum = [];
      var start = i;
      var result = null;
      var prevResult = null;

      for (times in 0...min) {
        result = this.action(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else return cast(prevResult);
      }

      for (times in 0...max) {
        result = this.action(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else break;
      }

      return mergeReplies(makeSuccess(i, accum), prevResult);
    });
  }

  /**
   * Expects parser at most n times. Yields an array of the results.
   */
  public function atMost(n : Int) : Parser<Array<A>> {
    return times(0, n);
  }

  /**
   * Expects parser at least n times. Yields an array of the results.
   */
  public function atLeast(n : Int) : Parser<Array<A>> {
    return seqMap([times(n), many()], function(results) {
      return results[0].concat(results[1]);
    });
  }

  /**
   * Yields an object with start, value, and end keys, where value is the original value yielded by the parser,
   * and start and end are are objects with a 0-based offset and 1-based line and column properties that represent
   * the position in the stream that contained the parsed text.
   */
  public function mark() : Parser<Mark<A>> {
    return index().chain(function(start) {
      return chain(function(value) {
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
   * Returns a new parser whose failure message is description. For example, string('x').desc('the letter x')
   * will indicate that 'the letter x' was expected.
   */
  public function desc(expected : String) : Parser<A> {
    return new Parser(function(stream, i) {
      var reply = this.action(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    });
  }

  /**
   * This is an alias for parser.or(other)
   */
  public function concat(other : Parser<A>) : Parser<A> {
    return or(other);
  }

  /**
   * Returns a new failed parser with 'empty' message
   */
  public function empty() : Parser<A> {
    return fail('empty');
  }

  /**
   * Makes `this` parser optional, and returns `None` in the case that
   * the parser does not accept the current input. Otherwise, if
   * `this` would have parsed and returned an `a`, `this.maybe()` will
   * parse and return a `Some(a)`.
   */
  public function maybe() : Parser<Option<A>> {
    return map(function(r) {
      return Some(r);
    }).or(of(None));
  }

  // Parser function
  private var action : String -> Int -> Data<A>;

  /**
   * The Parser object is a wrapper for a parser function.
   * Externally, you use one to parse a string by calling
   *   var result = SomeParser.parse('Me Me Me! Parse Me!');
   * You should never need to call the constructor, rather you should
   * construct your Parser from the base parsers and the
   * parser combinator methods.
   */
  private function new(action : String -> Int -> Data<A>) {
    this.action = action;
  }

  private static function makeSuccess<A>(index : Int, value : A) : Data<A> {
    return {
      status: true,
      index: index,
      value: value,
      furthest: -1,
      expected: []
    };
  }

  private static function makeFailure<A>(index : Int, expected : String) : Data<A> {
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

  private static function mergeReplies<A, B>(result : Data<A>, ?last : Data<B>) : Data<A> {
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