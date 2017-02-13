# Parsihax
[![TravisCI Build Status][travis-img]][travis]

Parsihax is a small library for writing big parsers made up of lots of little parsers. The API is inspired by
[parsec][] and [Parsimmon][parsimmon] (originally, Parsihax was just supposed to be Parsimmon rewrite in Haxe).

### Installation

Install the library via [haxelib][] (library manager that comes with any Haxe distribution).

```
haxelib install parsihax
```

## API Documentation

Haxe-generated API documentation is available at [documentation website][docs], or see the
[annotated source of `parsihax.Parser.hx`.][parsihax]

## Examples

See the [test][] directory for annotated examples of parsing JSON, simple Lisp-like structure and monad parser.

## Basics
To use nice sugar syntax, simply add this to your Haxe file

```haxe
import parsihax.*;
import parsihax.Parser.*;
using parsihax.Parser;
```

A `ParseObject` parser is an abstract that represents an action on a stream of text, and the promise of either an
object yielded by that action on success or a message in case of failure. For example, `Parser.string('foo')` yields
the string `'foo'` if the beginning of the stream is `'foo'`, and otherwise fails.

The method `.map` is used to transform the yielded value. For example,

```haxe
'foo'.string()
  .map(function(x) return x + 'bar');
```

will yield `'foobar'` if the stream starts with `'foo'`. The parser

```haxe
~/[0-9]+/.regexp()
  .map(function(x) return Std.parseInt(x) * 2);
```

will yield the number `24` when it encounters the string `'12'`.

Also, Parsihax supports nice sugar syntax thanks to Haxe operator overloading. For example,

```haxe
var a = "a".string() / "important letter a"
var b = "b".string() / "important letter b"
var c = "c".string() / "important letter c"

var result = a | b + c;

// Will succeed on "ac" and "bc"
// In case of failure, it will throw "expected important letter a|b|c"
// So, plus operator is alias to then, or operator to or and div
// operator to as
```

Getting `apply` from a `ParseObject` (or explicitly casting it to `ParseFunction` returns parsing function
`String -> ?Int -> Result<A>` (or just `ParseFunction`), that parses the string and returns a `Hax.Result`
with a boolean `status` flag, indicating whether the parse succeeded. If it succeeded, the `value` attribute will
contain the yielded value. Otherwise, the `index` and `expected` attributes will contain the offset of the parse error,
and a sorted, unique array of messages indicating what was expected.

The error object can be passed along with the original source to `ParseUtil.formatError` to obtain
a human-readable error string.

Changing `ParseObject.apply` value changes `ParseObject` behaviour, but still keeps it's reference, what is
really usefull in recursive parsers.

[travis]: https://travis-ci.org/deathbeam/parsihax
[travis-img]: https://api.travis-ci.org/deathbeam/parsihax.svg?branch=master
[haxelib]: http://lib.haxe.org/p/parsihax
[docs]: https://nondev.io/parsihax/parsihax/Parser.html
[parsihax]: https://github.com/deathbeam/parsihax/blob/master/src/parsihax/Parser.hx
[test]: https://github.com/deathbeam/parsihax/tree/master/test/parsihax
[parsec]: https://hackage.haskell.org/package/parsec
[parsimmon]: https://github.com/jneen/parsimmon
