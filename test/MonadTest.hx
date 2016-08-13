import Parsihax.*;
using Parsihax;

class MonadTest {
  public static function build() {
    return monad({
      a <= "a".string();
      b <= "b".string();
      c <= "c".string();
      ret([a,b,c]);
    });
  }
}