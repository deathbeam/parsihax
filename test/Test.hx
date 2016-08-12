package test;

import parsihax.Parser as P;

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

    switch(JSON.parse(json)) {
      case Success(value):
        trace(value);
      case Failure(index, expected):
        trace(P.formatError(json, index, expected));
    }

    var lisp = '( abc 89 ( c d 33 haleluje) )';

    switch(Lisp.parse(lisp)) {
      case Success(value):
        trace(value);
      case Failure(index, expected):
        trace(P.formatError(lisp, index, expected));
    }

    var spoon = 'do
      true
      "hello"
      67
      false
      null 
    end';

    switch(Spoon.parse(spoon)) {
      case Success(value):
        trace(value);
      case Failure(index, expected):
        trace(P.formatError(spoon, index, expected));
    }
  }
}