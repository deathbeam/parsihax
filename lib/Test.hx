import Parsihax as P;

class Test {
    public static function main() {
        var fooParser = P.string('foo')
            .map(function(x) { return x + 'bar'; });
        
        var numParser = P.regexp('[0-9]+')
            .map(function(x) { return Std.parseInt(x) * 2; });

        trace(fooParser.parse("foo"));
        trace(P.formatError("12a", numParser.parse("12a")));
    }
}