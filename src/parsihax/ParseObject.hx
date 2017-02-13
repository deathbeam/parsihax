package parsihax;

import haxe.ds.Vector;

/**
  The ParseObject object is a wrapper for a parser function.
  Externally, you use one to parse a string by calling
    `var result = SomeParseObject.apply('Me Me Me! Parse Me!');`
**/
abstract ParseObject<T>(Vector<ParseFunction<T>>) {

  inline function new() this = new Vector(1);
  @:to inline function get_apply() : ParseFunction<T> return this[0];
  inline function set_apply(param : ParseFunction<T>) return this[0] = param;

  /**
    Getting `ParseObject.apply` from a parser (or explicitly casting it to
    `ParseFunction` returns parsing function `String -> ?Int -> ParseResult<A>`
    (or just `ParseFunction`), that parses the string and returns `ParseResult<A>`.

    Changing `ParseObject.apply` value changes parser behaviour, but still keeps it's
    reference, what is really usefull in recursive parsers.
  **/
  public var apply(get, set): ParseFunction<T>;

  /**
    Creates `ParseObject` from `ParseFunction`
  **/
  @:noUsing @:from public static inline function to<T>(v : ParseFunction<T>) : ParseObject<T> {
    var ret = new ParseObject();
    ret.apply = v;
    return ret;
  }

  /**
    Same as `Hax.then(l, r)`
  **/
  @:noUsing @:op(A + B) public static inline function opAdd<A, B>(l: ParseObject<A>, r: ParseObject<B>): ParseObject<B> {
    return Parser.then(l, r);
  }

  /**
    Same as `Hax.or(l, r)`
  **/
  @:noUsing @:op(A | B) public static inline function opOr<A>(l: ParseObject<A>, r: ParseObject<A>): ParseObject<A> {
    return Parser.or(l, r);
  }

  /**
    Same as `Hax.as(l, r)`
  **/
  @:noUsing @:op(A / B) public static inline function opDiv<A>(l: ParseObject<A>, r: String): ParseObject<A> {
    return Parser.as(l, r);
  }

}
