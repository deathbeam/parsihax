import Parsihax.*;
import Parsihax.Util.*;

typedef Index = {
  var offset: Int;
  @:optional var line: Int;
  @:optional var column: Int;
}

typedef Result = {
  @:optional var status : Bool;
  @:optional var index : Int;
  @:optional var value: Dynamic;
  @:optional var furthest: Int;
  @:optional var expected : Array<String>;
};

abstract DynamicObject<T>(Dynamic<T>) from Dynamic<T> {
  public inline function new() { this = {}; }
  @:arrayAccess public inline function set(key:String, value:T):Void { Reflect.setField(this, key, value); }
  @:arrayAccess public inline function get(key:String):Null<T> { #if js return untyped this[key]; #else return Reflect.field(this, key);#end }
  public inline function exists(key:String):Bool { return Reflect.hasField(this, key); }
  public inline function remove(key:String):Bool { return Reflect.deleteField(this, key); }
  public inline function keys():Array<String> { return Reflect.fields(this); }
}

// From this: https://github.com/jneen/parsimmon/blob/master/API.md
class Parsihax {
  public static var letter = regexp('[a-z]/i').desc('a letter');
  public static var letters = regexp('[a-z]*/i');
  public static var digit = regexp('[0-9]').desc('a digit');
  public static var digits = regexp('[0-9]*');
  public static var whitespace = regexp('\\s+').desc('whitespace');
  public static var optWhitespace = regexp('\\s*');

  public static var any = new Parser(function(stream, i) {
    if (i >= stream.length) return makeFailure(i, 'any character');

    return makeSuccess(i+1, stream.charAt(i));
  });

  public static var all = new Parser(function(stream, i) {
    return makeSuccess(stream.length, stream.substr(i));
  });

  public static var eof = new Parser(function(stream, i) {
    if (i < stream.length) return makeFailure(i, 'EOF');

    return makeSuccess(i, null);
  });

  public static var index = new Parser(function(stream, i) {
    return makeSuccess(i, makeLineColumnIndex(stream, i));
  });

  public static function string(str) {
    var len = str.length;
    var expected = "'"+str+"'";

    return new Parser(function(stream, i) {
      var head = stream.substr(i, i+len);

      if (head == str) {
        return makeSuccess(i+len, head);
      } else {
        return makeFailure(i, expected);
      }
    });
  }

  public static function oneOf(str) {
    return test(function(ch) { return str.indexOf(ch) >= 0; });
  }

  public static function noneOf(str) {
    return test(function(ch) { return str.indexOf(ch) < 0; });
  }

  public static function regexp(re, group = 0) {
    assertRegexp(re);
    
    var inner = re;
    var ind =  re.lastIndexOf('/');

    if (ind != -1) {
      inner = re.substr(0, ind);
    }
    
    var anchored = new EReg('^(?:' + inner + ')', flags(re));
    var expected = re;

    return new Parser(function(stream, i) {
      var match = anchored.matchSub(stream, i);

      if (match) {
        var fullMatch = anchored.matched(0);
        var groupMatch = anchored.matched(group);
        if (groupMatch != null) {
          return makeSuccess(i + fullMatch.length, groupMatch);
        }
      }

      trace("Jello" + expected);
      return makeFailure(i, expected);
    });
  }

  public static function succeed(value) {
    return new Parser(function(stream, i) {
      return makeSuccess(i, value);
    });
  }

  public static function of(value) {
    return succeed(value);
  }

  public static function seq(parsers : Array<Parser>) {
    var numParsers = parsers.length;

    return new Parser(function(stream, i) {
      var result = null;
      var accum : Array<Dynamic> = [];

      for (parser in parsers) {
        result = mergeReplies(parser.action(stream, i), result);
        if (!result.status) return result;
        accum.push(result.value);
        i = result.index;
      }

      return mergeReplies(makeSuccess(i, accum), result);
    });
  }

  public static function seqMap(parsers, mapper) {
    return seq(parsers).map(function(results) {
      return mapper(results);
    });
  }

  public static function alt(parsers : Array<Parser>) {
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

  public static function sepBy(parser, separator) {
    return sepBy1(parser, separator).or(of([]));
  }

  public static function sepBy1(parser, separator) {

    var pairs = separator.then(parser).many();

    return parser.chain(function(r) {
      return pairs.map(function(rs) {
        return [r].concat(rs);
      });
    });
  }

  public static function lazy(f, ?desc) {
    var parser = new Parser(null);

    parser.action = function(stream, i) {
      parser.action = f().action;
      return parser.action(stream, i);
    }

    if (desc != null) parser = parser.desc(desc);
    return parser;
  }

  public static function fail(expected) {
    return new Parser(function(stream, i) { return makeFailure(i, expected); });
  }

  public static function test(predicate) {
    return new Parser(function(stream, i) {
      var char = stream.charAt(i);
      if (i < stream.length && predicate(char)) {
        return makeSuccess(i+1, char);
      }
      else {
        return makeFailure(i, 'a character matching '+predicate);
      }
    });
  }

  public static function takeWhile(predicate) {
    return new Parser(function(stream, i) {
      var j = i;
      while (j < stream.length && predicate(stream.charAt(j))) j += 1;
      return makeSuccess(j, stream.substr(i, j));
    });
  }

  public static function custom(parsingFunction) {
    return new Parser(parsingFunction(makeSuccess, makeFailure));
  }

  public static function formatError(stream, error) {
    return 'expected ' + formatExpected(error.expected) + formatGot(stream, error);
  }
}

// The Parser object is a wrapper for a parser function.
// Externally, you use one to parse a string by calling
//   var result = SomeParser.parse('Me Me Me! Parse Me!');
// You should never call the constructor, rather you should
// construct your Parser from the base parsers and the
// parser combinator methods.
class Parser {
  public var action : String -> Int -> Result;

  public function new(action : String -> Int -> Result) {
    this.action = action;
  }

  public function parse(stream) : Result {
    if (!Std.is(stream, String)) {
      throw '.parse must be called with a string as its argument';
    }

    var result = this.skip(eof).action(stream, 0);

    return result.status ? {
      status: true,
      value: result.value
    } : {
      status: false,
      index: result.furthest,
      expected: result.expected
    };
  }

  public function or(alternative) {
    return alt([this, alternative]);
  }

  public function chain(f) {
    var self = this;
    return new Parser(function(stream, i) {
      var result = self.action(stream, i);
      if (!result.status) return result;
      var nextParser = f(result.value);
      return mergeReplies(nextParser.action(stream, result.index), result);
    });
  }

  public function then(next) {
    return seq([this, next]).map(function(results) { return results[1]; });
  }

  public function map(fn) {
    var self = this;
    return new Parser(function(stream, i) {
      var result = self.action(stream, i);
      if (!result.status) return result;
      return mergeReplies(makeSuccess(result.index, fn(result.value)), result);
    });
  }

  public function result(res) {
    return this.map(function(_) { return res; });
  }

  public function skip(next) {
    return seq([this, next]).map(function(results) {
      return results[0];
    });
  };

  public function many() {
    var self = this;

    return new Parser(function(stream, i) {
      var accum = [];
      var result = null;
      var prevResult = null;

      while (true) {
        result = mergeReplies(self.action(stream, i), result);

        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else {
          return mergeReplies(makeSuccess(i, accum), result);
        }
      }
    });
  }

  public function times(min, ?max) {
    if (max == null) max = min;
    var self = this;

    return new Parser(function(stream, i) {
      var accum = [];
      var start = i;
      var result = null;
      var prevResult = null;

      for (times in 0...min) {
        result = self.action(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else return prevResult;
      }

      for (times in 0...max) {
        result = self.action(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        }
        else break;
      }

      return mergeReplies(makeSuccess(i, accum), prevResult);
    });
  }

  public function atMost(n) {
    return this.times(0, n);
  }

  public function atLeast(n) {
    var self = this;
    return seqMap([this.times(n), this.many()], function(results) {
      return results[0].concat(results[1]);
    });
  }

  public function mark() {
    return seqMap([index, this, index], function(results) {
      return { start: results[0], value: results[1], end: results[2] };
    });
  }

  public function desc(expected : String) {
    var self = this;
    return new Parser(function(stream, i) {
      var reply = self.action(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    });
  }

  public function concat(other) {
    return or(other);
  }

  public function empty() {
    return fail('empty');
  }

  public function ap(other) {
    return seqMap([this, other], function(results) { return results[0](results[1]); });
  }

  public function of(value) {
    return Parsihax.of(value);
  }
}

class Util {
  public static function makeSuccess(index : Int, value) : Result {
    return {
      status: true,
      index: index,
      value: value,
      furthest: -1,
      expected: []
    };
  }

  public static function makeFailure(index : Int, expected : String) : Result {
    return {
      status: false,
      index: -1,
      value: null,
      furthest: index,
      expected: [expected]
    };
  }

  public static function mergeReplies(result : Result, ?last : Result) : Result {
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

  // Returns the sorted set union of two arrays of strings. Note that if both
  // arrays are empty, it simply returns the first array, and if exactly one
  // array is empty, it returns the other one unsorted. This is safe because
  // expectation arrays always start as [] or [x], so as long as we merge with
  // this function, we know they stay in sorted order.
  public static function unsafeUnion(xs : Array<String>, ys : Array<String>) : Array<String> {
    // Exit early if either array is empty (common case)
    var xn = xs.length;
    var yn = ys.length;
    if (xn == 0) {
      return ys;
    } else if (yn == 0) {
      return xs;
    }
    // Two non-empty arrays: do the full algorithm
    var obj : DynamicObject<Bool> = {};

    var i = 0;
    while (i < xn) {
      obj[xs[i]] = true;
      i++;
    }
    i = 0;
    while (i < yn) {
      obj[ys[i]] = true;
      i++;
    }

    var keys = [];

    for (k in obj.keys()) {
      keys.push(k);
    }

    keys.sort(function(a, b):Int {
        a = a.toLowerCase();
        b = b.toLowerCase();
        if (a < b) return -1;
        if (a > b) return 1;
        return 0;
    });

    return keys;
  }

  public static function assertRegexp(x) {
    if (!Std.is(x, String)) {
      throw 'not a regexp: '+x;
    }

    var f = flags(x);
    var i = 0;
    while (i < f.length) {
      var c = f.charAt(i);
      // Only allow regexp flags [imu] for now, since [g] and [y] specifically
      // mess up Parsihax. If more non-stateful regexp flags are added in the
      // future, this will need to be revisited.
      if (c != 'i' && c != 'm' && c != 'u') {
        throw 'unsupported regexp flag "' + c + '": ' + x;
      }
      i++;
    }
  }

  public static function formatExpected(expected : Array<String>) {
    if (expected.length == 1) return expected[0];

    return 'one of ' + expected.join(', ');
  }

  public static function formatGot(stream : String, error : Result) {
    var index = makeLineColumnIndex(stream, error.index);
    var i = index.offset;

    if (i == stream.length) return ', got the end of the stream';

    var prefix = (i > 0 ? "'..." : "'");
    var suffix = (stream.length - i > 12 ? "...'" : "'");

    return ' at line ' + index.line + ' column ' + index.column
      +  ', got ' + prefix + stream.substr(i, i+12) + suffix;
  }

  public static function flags(re : String) {
    var res = '';
    var ind = re.lastIndexOf('/');

    if (ind != -1) {
      res = re.substr(ind + 1);
    }

    return res;
  };

  public static function makeLineColumnIndex(stream : String, i : Int) : Index {
    var lines = stream.substr(0, i).split("\n");
    // Note that unlike the character offset, the line and column offsets are
    // 1-based.
    var lineWeAreUpTo = lines.length;
    var columnWeAreUpTo = lines[lines.length - 1].length + 1;

    return {
      offset: i,
      line: lineWeAreUpTo,
      column: columnWeAreUpTo
    };
  };
}