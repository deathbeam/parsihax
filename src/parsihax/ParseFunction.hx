package parsihax;

/**
  Parsing function created by chaining Parser combinators.
**/
typedef ParseFunction<A> = String -> ?Int -> ParseResult<A>;
