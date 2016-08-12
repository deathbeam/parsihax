package test;

import parsihax.Parser.Result;
import parsihax.Parser.formatError;

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

    printAndParse('JSON', json, JSON.parse(json));

    var lisp = '( abc 89 ( c d 33 haleluje) )';

    printAndParse('Lisp', lisp, Lisp.parse(lisp));
  }

  private static function printAndParse<T>(name : String, input : String, output : Result<T>) {
    Sys.println('-----------------------------------');
    Sys.println('Parser input ($name)');
    Sys.println('-----------------------------------');
    Sys.println('    $input');
    Sys.println('-----------------------------------');
    Sys.println('Parser output ($name)');
    Sys.println('-----------------------------------');
    
    Sys.println(switch(output) {
      case Success(value):
        value;
      case Failure(index, expected):
        formatError(input, index, expected);
    });
  }
}