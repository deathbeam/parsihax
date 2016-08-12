# Parsihax
[![TravisCI Build Status](https://api.travis-ci.org/deathbeam/parsihax.svg?branch=master)](https://travis-ci.org/deathbeam/parsihax)

`Parsihax` is a small library for writing big parsers made up of lots of little parsers. The API is inspired by [parsec][] and [Promises/A+][promises-aplus].
Originally, it started by rewriting [Parsimmon][parsimmon] to Haxe.

## Examples
See the [test][] directory for annotated examples of parsing JSON and simple Lisp-like structure.

## Basics

A `Parsihax` parser is an object that represents an action on a stream of text, and the promise of either an object yielded by that action on success or a message in case of failure. For example, `Parser.string('foo')` yields the string `'foo'` if the beginning of the stream is `'foo'`, and otherwise fails. To use nice sugar syntax, simply add this to your Haxe file

```haxe
import parsihax.Parser.*;
using parsihax.Parser;
```

The method `.map` is used to transform the yielded value. For example,

```haxe
'foo'.string()
  .map(function(x) return x + 'bar')
```

will yield `'foobar'` if the stream starts with `'foo'`. The parser

```haxe
~/[0-9]+/.regexp()
  .map(function(x) return Std.parseInt(x) * 2)
```

will yield the number `24` when it encounters the string `'12'`.

Calling `.parse(string)` on a parser parses the string and returns an enum with that can be `Success(value)` or `Failure(index, expected)`, indicating whether the parse succeeded. If it succeeded, the `value` attribute will contain the yielded value. Otherwise, the `index` and `expected` attributes will contain the index of the parse error (with `offset`, `line` and `column` properties), and a sorted, unique array of messages indicating what was expected.

The failure results can be passed along with the original source to `Parser.formatError(source, index, expected)` to obtain a human-readable error string.

[test]: https://github.com/deathbeam/parsihax/tree/master/test

[promises-aplus]: https://promisesaplus.com/
[parsec]: https://hackage.haskell.org/package/parsec
[parsimmon]: https://github.com/jneen/parsimmon