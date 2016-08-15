# Parsihax
[![TravisCI Build Status](https://api.travis-ci.org/deathbeam/parsihax.svg?branch=master)](https://travis-ci.org/deathbeam/parsihax)

`Parsihax` is a small library for writing big parsers made up of lots of little parsers. The API is inspired by
[parsec][], [Promises/A+][promises-aplus] and [Parsimmon][parsimmon] (originally, `Parsihax` was just supposed to be
Parsimmon rewrite in Haxe).

## API Documentation

Haxe-generated API documentation is available at [documentation website][docs], or see the 
[annotated source of `Parsihax.hx`.][parsihax]

## Examples

See the [test][] directory for annotated examples of parsing JSON, simple Lisp-like structure and monad parser.

## Basics
To use nice sugar syntax, simply add this to your Haxe file

```haxe
import Parsihax.*;
using Parsihax;
```

A `Parsihax.Parser` parser is an abstract that represents an action on a stream of text, and the promise of either an
object yielded by that action on success or a message in case of failure. For example, `Parsihax.string('foo')` yields
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

Also, `Parsihax` supports nice monad sugar syntax (thanks to [monax][]). For example,

```haxe
monad({
  a <= "a".string();
  b <= "b".string();
  c <= "c".string();
  ret([a,b,c]);
});
```

will yield `[ 'a', 'b', 'c']` when it encounters the string `'abc'`.

Getting `parse` from a `Parsihax.Parser` (or explicitly casting it to `Parsihax.Function` returns parsing function
`String -> ?Int -> Result<A>` (or just `Parsihax.Function`), that parses the string and returns a `Parsihax.Result`
with a boolean `status` flag, indicating whether the parse succeeded. If it succeeded, the `value` attribute will
contain the yielded value. Otherwise, the `index` and `expected` attributes will contain the offset of the parse error,
and a sorted, unique array of messages indicating what was expected.

The error object can be passed along with the original source to `Parsihax.formatError` to obtain
a human-readable error string.

Changing `Parsihax.Parser.parse` value changes `Parsihax.Parser` behaviour, but still keeps it's reference, what is
really usefull in recursive parsers.

[docs]: https://deathbeam.github.io/parsihax/Parsihax.html
[parsihax]: https://github.com/deathbeam/parsihax/blob/master/src/Parsihax.hx
[test]: https://github.com/deathbeam/parsihax/tree/master/test

[monax]: https://github.com/sledorze/monax
[promises-aplus]: https://promisesaplus.com/
[parsec]: https://hackage.haskell.org/package/parsec
[parsimmon]: https://github.com/jneen/parsimmon