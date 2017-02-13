package parsihax;

/**
  A structure with a boolean `status` flag, indicating whether the parse
  succeeded. If it succeeded, the `value` attribute will contain the yielded
  value. Otherwise, the `index` and `expected` attributes will contain the
  offset of the parse error, and a sorted, unique array of messages indicating
  what was expected.

  The error structure can be passed along with the original source to
  `Parser.formatError` to obtain a human-readable error string.
**/
typedef ParseResult<T> = {

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

}
