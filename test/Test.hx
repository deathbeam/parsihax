import Parsihax.Result;
import Parsihax.formatError;

class Test {
  public static function main() {
    var json = '{
      "firstName": "John",
      "lastName": "Smith",
      "age": 25,
      "address": {
        "streetAddress": "21 2nd Street",
        "city": "New York",
        "state": "NY",
        "postalCode": "10021"
      },
      "phoneNumber": [
        {
          "type": "home",
          "number": "212 555-1234"
        },
        {
          "type": "fax",
          "number": "646 555-4567"
        }
      ]
    }';

    printAndParse('JSON', json, JSONTest.parse(json));

    var lisp = '( abc 89 ( c d 33 haleluje) )';

    printAndParse('Lisp', lisp, LispTest.parse(lisp));

    var monad = "abc";

    printAndParse('Monad', monad, MonadTest.parse(monad));
  }

  private static function printAndParse<T>(name : String, input : String, output : Result<T>) {
    trace('-----------------------------------');
    trace('Parser input ($name)');
    trace('-----------------------------------');
    trace('$input');
    trace('-----------------------------------');
    trace('Parser output ($name)');
    trace('-----------------------------------');

    trace(output.status
      ? Std.string(output.value)
      : formatError(output, input)
    );
  }
}