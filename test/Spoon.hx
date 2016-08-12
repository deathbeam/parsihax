package test;

import parsihax.Parser;
import parsihax.Parser.*;

class Spoon {
  public static function parse(text : String) {
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

    // Literals
    var String = token(regexp(~/"((?:\\.|.)*?)"/, 1)).desc('string');
    var Number = token(regexp(~/-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?/)).desc('number');
    var True = token(string('true'));
    var False = token(string('false'));
    var Null = token(string('null'));
    var Literal = alt([ String, Number, True, False, Null ]);

    // Operators

    // Grammar
    var Statement : Parser<Dynamic> = Literal;
    var Body : Parser<Dynamic> = Statement.many();
    var Block : Parser<Dynamic> = Do.then(Body).skip(End).or(Statement);

    spoon.set(lazy(function() {
      return spaces.then(Block).skip(eof());
    }));

    return spoon.parse(text);
  }
}