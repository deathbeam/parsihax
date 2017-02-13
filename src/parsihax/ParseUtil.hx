package parsihax;

class ParseUtil {

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
  @:allow(parsihax.Parser)
  private static inline function makeSuccess<A>(index : Int, value : A) : ParseResult<A> {
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
  @:allow(parsihax.Parser)
  private static inline function makeFailure<A>(index : Int, expected : String) : ParseResult<A> {
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
  @:allow(parsihax.Parser)
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


