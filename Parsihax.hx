import Parsihax.Util.*;

// TODO: Follow this: https://github.com/jneen/parsimmon/blob/master/API.md
class Parsihax {
  public static var letter = regexp(~/[a-z]/i).desc('a letter');
  public static var letters = regexp(~/[a-z]*/i);
  public static var digit = regexp(~/[0-9]/).desc('a digit');
  public static var digits = regexp(~/[0-9]*/);
  public static var whitespace = regexp(~/\s+/).desc('whitespace');
  public static var optWhitespace = regexp(~/\s*/);

  public static var any = Parser(function(stream, i) {
    if (i >= stream.length) return makeFailure(i, 'any character');

    return makeSuccess(i+1, stream.charAt(i));
  });

  public static var all = Parser(function(stream, i) {
    return makeSuccess(stream.length, stream.slice(i));
  });

  public static var eof = Parser(function(stream, i) {
    if (i < stream.length) return makeFailure(i, 'EOF');

    return makeSuccess(i, null);
  });

  public static var index = Parser(function(stream, i) {
    return makeSuccess(i, makeLineColumnIndex(stream, i));
  });

  public static function string(str) {
    var len = str.length;
    var expected = "'"+str+"'";

    assertString(str);

    return Parser(function(stream, i) {
      var head = stream.slice(i, i+len);

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

    if (group != 0) {
      assertNumber(group);
    }

    var anchored = RegExp('^(?:' + re.source + ')', flags(re));
    var expected = '' + re;

    return Parser(function(stream, i) {
      var match = anchored.exec(stream.slice(i));

      if (match) {
        var fullMatch = match[0];
        var groupMatch = match[group];
        if (groupMatch != null) {
          return makeSuccess(i + fullMatch.length, groupMatch);
        }
      }

      return makeFailure(i, expected);
    });
  }

  public static function succeed(value) {
    return Parser(function(stream, i) {
      return makeSuccess(i, value);
    });
  }

  public static function of(value) {
    return succeed(value);
  }

  public static function seq(parsers) {
    var numParsers = parsers.length;

    for (parser in parsers) {
      assertParser(parser);
    }

    return Parser(function(stream, i) {
      var result;
      var accum = new Array(numParsers);

      for (parser in parsers) {
        result = mergeReplies(parser._(stream, i), result);
        if (!result.status) return result;
        accum.add(result.value);
        i = result.index;
      }

      return mergeReplies(makeSuccess(i, accum), result);
    });
  }

  public static function seqMap(parsers, mapper) {
    assertFunction(mapper);

    return seq(parsers).map(function(results) {
      return mapper(results);
    });
  }

  public static function alt(parsers) {
    var numParsers = parsers.length;
    if (numParsers == 0) return fail('zero alternates');

    for (parser in parsers) {
      assertParser(parser);
    }

    return Parser(function(stream, i) {
      var result;
      for (parser in parsers) {
        result = mergeReplies(parser._(stream, i), result);
        if (result.status) return result;
      }
      return result;
    });
  }

  public static function sepBy(parser, separator) {
    return sepBy1(parser, separator).or(Parsimmon.of([]));
  }

  public static function sepBy1(parser, separator) {
    assertParser(parser);
    assertParser(separator);

    var pairs = separator.then(parser).many();

    return parser.chain(function(r) {
      return pairs.map(function(rs) {
        return [r].concat(rs);
      });
    });
  }

  public static function lazy(f, ?desc) {
    var parser = Parser(function(stream, i) {
      parser._ = f()._;
      return parser._(stream, i);
    });

    if (desc != null) parser = parser.desc(desc);
    return parser;
  }

  public static function fail(expected) {
    return Parser(function(stream, i) { return makeFailure(i, expected); });
  }

  public static function test(predicate) {
    assertFunction(predicate);

    return Parser(function(stream, i) {
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
    assertFunction(predicate);

    return Parser(function(stream, i) {
      var j = i;
      while (j < stream.length && predicate(stream.charAt(j))) j += 1;
      return makeSuccess(j, stream.slice(i, j));
    });
  }

  public static function custom(parsingFunction) {
    return Parser(parsingFunction(makeSuccess, makeFailure));
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
  public var _;

  public function new(action) {
    this._ = action;
  }

  public function parse(stream) {
    if (!Std.is(stream, String)) {
      throw new Error('.parse must be called with a string as its argument');
    }

    var result = this.skip(eof)._(stream, 0);

    return result.status ? {
      status: true,
      value: result.value
    } : {
      status: false,
      index: makeLineColumnIndex(stream, result.furthest),
      expected: result.expected
    };
  }

  public function or(alternative) {
    return alt(this, alternative);
  }

  public function chain(f) {
    var self = this;
    return Parser(function(stream, i) {
      var result = self._(stream, i);
      if (!result.status) return result;
      var nextParser = f(result.value);
      return mergeReplies(nextParser._(stream, result.index), result);
    });
  }

  public function then(next) {
    assertParser(next);
    return seq(this, next).map(function(results) { return results[1]; });
  }

  public function map(fn) {
    assertFunction(fn);

    var self = this;
    return Parser(function(stream, i) {
      var result = self._(stream, i);
      if (!result.status) return result;
      return mergeReplies(makeSuccess(result.index, fn(result.value)), result);
    });
  }

  public function result(res) {
    return this.map(function(_) { return res; });
  }

  public function skip(next) {
    return seq(this, next).map(function(results) {
      return results[0];
    });
  };

  public function many() {
    var self = this;

    return Parser(function(stream, i) {
      var accum = [];
      var result;
      var prevResult;

      while (true) {
        result = mergeReplies(self._(stream, i), result);

        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else {
          return mergeReplies(makeSuccess(i, accum), result);
        }
      }
    });
  }

  public function times(min, max) {
    if (arguments.length < 2) max = min;
    var self = this;

    assertNumber(min);
    assertNumber(max);

    return Parser(function(stream, i) {
      var accum = [];
      var start = i;
      var result;
      var prevResult;

      for (times in 0...min) {
        result = self._(stream, i);
        prevResult = mergeReplies(result, prevResult);
        if (result.status) {
          i = result.index;
          accum.push(result.value);
        } else return prevResult;
      }

      for (times in 0...max) {
        result = self._(stream, i);
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
    return seqMap(this.times(n), this.many(), function(init, rest) {
      return init.concat(rest);
    });
  }

  public function mark() {
    return seqMap(index, this, index, function(start, value, end) {
      return { start: start, value: value, end: end };
    });
  }

  public function desc(expected) {
    var self = this;
    return Parser(function(stream, i) {
      var reply = self._(stream, i);
      if (!reply.status) reply.expected = [expected];
      return reply;
    });
  }
}

class Util {
  public static function makeSuccess(index, value) {
    return {
      status: true,
      index: index,
      value: value,
      furthest: -1,
      expected: []
    };
  }

  public static function makeFailure(index, expected) {
    return {
      status: false,
      index: -1,
      value: null,
      furthest: index,
      expected: [expected]
    };
  }

  public static function mergeReplies(result, last) {
    if (!last) return result;
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
  public static function unsafeUnion(xs, ys) {
    // Exit early if either array is empty (common case)
    var xn = xs.length;
    var yn = ys.length;
    if (xn == 0) {
      return ys;
    } else if (yn == 0) {
      return xs;
    }
    // Two non-empty arrays: do the full algorithm
    var obj = {};
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
    for (k in obj) {
      if (obj.hasOwnProperty(k)) {
        keys.push(k);
      }
    }
    keys.sort();
    return keys;
  }

  // For ensuring we have the right argument types
  public static function assertParser(p) {
    if (!Std.is(p, Parser)) {
      throw new Error('not a parser: ' + p);
    }
  }

  public static function assertNumber(x) {
    if (!Std.is(x, Float) && !Std.is(x, Int)) {
      throw new Error('not a number: ' + x);
    }
  }

  public static function assertRegexp(x) {
    if (!Std.is(x, EReg)) {
      throw new Error('not a regexp: '+x);
    }

    var f = flags(x);
    var i = 0;
    while (i < f.length) {
      var c = f.charAt(i);
      // Only allow regexp flags [imu] for now, since [g] and [y] specifically
      // mess up Parsihax. If more non-stateful regexp flags are added in the
      // future, this will need to be revisited.
      if (c != 'i' && c != 'm' && c != 'u') {
        throw new Error('unsupported regexp flag "' + c + '": ' + x);
      }
      i++;
    }
  }

  public static function assertFunction(x) {
    if (!Reflect.isFunction(x)) {
      throw new Error('not a function: ' + x);
    }
  }

  public static function assertString(x) {
    if (!Std.is(x, String)) {
      throw new Error('not a string: ' + x);
    }
  }

  public static function formatExpected(expected) {
    if (expected.length == 1) return expected[0];

    return 'one of ' + expected.join(', ');
  }

  public static function formatGot(stream, error) {
    var index = error.index;
    var i = index.offset;

    if (i == stream.length) return ', got the end of the stream';


    var prefix = (i > 0 ? "'..." : "'");
    var suffix = (stream.length - i > 12 ? "...'" : "'");

    return ' at line ' + index.line + ' column ' + index.column
      +  ', got ' + prefix + stream.slice(i, i+12) + suffix;
  }

  public static function flags(re) {
    var s = '' + re;
    return s.slice(s.lastIndexOf('/') + 1);
  };

  public static function makeLineColumnIndex(stream, i) {
    var lines = stream.slice(0, i).split("\n");
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

//- fantasyland compat

//- Monoid (Alternative, really)
//_.concat = _.or;
//_.empty = fail('empty')

//- Applicative
//_.of = Parser.of = Parsimmon.of = succeed

//_.ap = function(other) {
//  return seqMap(this, other, function(f, x) { return f(x); })
//};