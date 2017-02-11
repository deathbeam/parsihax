package parsi;

import parsi.Hax;
import buddy.SingleSuite;
using buddy.Should;

class Test extends SingleSuite {
  public function new() {
    describe("Using Parsihax", {
      var result = false;

      beforeEach({
        result = false;
      });

      describe("JSON grammar", {
        var input = '
        {
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

        beforeEach({
          result = JsonGrammar.build()(input).status;
        });

        it('should parse "$input"', {
          result.should.be(true);
        });
      });

      describe("Lisp grammar", {
        var input = '
          (if (empty brain)
            (print "Hello Lisp!")
            (print 42.0))';

        beforeEach({
          result = LispGrammar.build()(input).status;
        });

        it('should parse "$input"', {
          result.should.be(true);
        });
      });

    });
  }
}
