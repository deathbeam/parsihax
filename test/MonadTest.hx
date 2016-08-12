package test;

import parsihax.Parsihax.*;
using parsihax.Parsihax;

class MonadTest {
  public static function parse(text : String) {
    return monad({
      a <= "a".string();
      b <= "b".string();
      c <= "c".string();
      ret([a,b,c]);
    }).parse(text);
  }
}