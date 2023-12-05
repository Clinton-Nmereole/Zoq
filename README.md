# Zoq

Simple expression transformer written in Zig, based on project of similar name [Coq](https://coq.inria.fr/) and inspired by [Noq](https://github.com/tsoding/Noq)

## Installation
```console

git clone https://github.com/Clinton-Nmereole/Zoq

cd Zoq

zig build run

```

## Usage

The current functionality of the REPL is limited to simply parsing user input into an expression.

### What is an Expression?

An expression at the moment can be thought of as two things:
- A symbol
- A function

### What is a Symbol?
A symbol is a struct that is just a string literal. For example, 'x' is a symbol. But a symbol can also be longer than one character so 'hello' is also a symbol.

### What is a Function?
A function is a struct that has fields 'name' and 'arguments'. The 'name' field is a string literal and the 'arguments' is an array/slice of Expressions(symbols or functions) For example, 'add(x, y)' is a function with the name add and arguments [x, y] and x and y in this case are Expressions of the type Symbols. We could also have 'add(f(x), g(y))' which would be a function whose arguments are other functions [f(x), g(y)].                    

### What is a Rule?
A rule is a struct that has fields 'expression' and 'equivalent'. Both fields are Expressions. A Rule works on the principle of 'add(x, y) ≡ add(y, x)'.
It tells us that the field 'expression' is mathematically equivalent to the field 'equivalent'.\
Rule has a method 'apply', that takes an Expression pattern matches it to the Rules expression field and returns the equivalent to the entered Expression.
Example:

```console
Rule => add(x, y) ≡ add(y, x)
Input Expression: add(a, b)
Rule.apply(Input Expression) => add(b, a)
```



## References
Coq: [https://coq.inria.fr/](https://coq.inria.fr/)\
Noq: [https://github.com/tsoding/Noq](https://github.com/tsoding/Noq)\
comath: [https://github.com/InKryption/comath](https://github.com/InKryption/comath)\
Zig Documentation:[https://ziglang.org/documentation/master](https://ziglang.org/documentation/master)\
Dmitry Soshnikov's Youtube Videos: [https://www.youtube.com/watch?v=4m7ubrdbWQU&t=241s](https://www.youtube.com/watch?v=4m7ubrdbWQU&t=241s)\
Metaprogramming in Zig and parsing CSS: [https://notes.eatonphil.com/2023-06-19-metaprogramming-in-zig-and-parsing-css.html](https://notes.eatonphil.com/2023-06-19-metaprogramming-in-zig-and-parsing-css.html)\
Zig Comptime - WTF is Comptime (and Inline) - Zig News: [https://zig.news/edyu/wtf-is-zig-comptime-and-inline-257b](https://zig.news/edyu/wtf-is-zig-comptime-and-inline-257b)
