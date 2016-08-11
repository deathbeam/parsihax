package examples;

import parsihax.Parser.*;

class Spoon {
  public static function main() {
    var spoon = ref();

    var spaces = optWhitespace();
    function token(parser) {
      return parser.skip(spaces);
    }

    // Keywords
    var Do = token(string('do'));
    var End = token(string('end'));
    var If = token(string('if'));
    var Else = token(string('else'));
    var For = token(string('for'));
    var While = token(string('while'));
    var Function = token(string('function'));
    var Return = token(string('return'));
    var Break = token(string('break'));
    var Continue = token(string('continue'));
    var Null = token(string('null'));
    var True = token(string('true'));
    var False = token(string('false'));

    // Operators

    // Grammar
    var Statement = alt([True, False, Null]);
    var Body = Statement.many();
    var Block = Do.then(Body).skip(End).or(Statement);

    spoon.set(lazy(function() {
      return spaces.then(Block).skip(eof());
    }));

    var text = 'do
      true
      false
      null 
    end';

    switch(spoon.parse(text)) {
      case Success(value):
        trace(value);
      case Failure(index, expected):
        trace(formatError(text, index, expected));
    }
  }
}