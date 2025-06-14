# SPICY Compiler

A minimal compiler for the **SPICY** programming language, written in OCaml. It parses, type-checks, and compiles SPICY source code to LLVM IR.

---

## Features

- **Language support**: Integers, booleans, strings, functions, if/elseif/else, for/while/do-while loops, variables, and printing.
- **Type Checking**: Basic type inference and checking for expressions and statements.
- **LLVM IR Generation**: Emits IR for execution with LLVM toolchain.
- **OCaml Toolchain**: Uses Menhir for parsing and OCamlex for lexing.
- **Test Scripts**: Example programs and LLVM output provided in the `tests/` directory.

---

## Language Overview

### Example Program (see `test2.spicy`)

```javascript
fun add(x, y) {
  x + y
}

let a = 3
let b = 4
print add(a, b)

if true {
  print "This is true"
} elseif false {
  print "This won't run"
} else {
  print "Fallback"
}

for i in 0..2 {
  print i
}
```

Supported features:
- Variables: `let a = 10`
- Functions: `fun f(x, y) { ... }`
- Conditionals: `if {...} elseif {...} else {...}`
- Loops: `for`, `while`, `do-while`
- Basic types: `Int`, `Bool`, `String`
- Print statement

---

## Building

### Prerequisites

- OCaml (4.x)
- Menhir
- OCamlex
- LLVM (for IR execution and further processing)
- GCC (for final machine code, optional)

### Build

Make sure you are in the project root, then run:

```sh
make
```

or for Windows MinGW64:

```sh
make -f Makefile_win_mingw64
```

This will:
1. Build the SPICY compiler frontend (`spicyc`)
2. Generate LLVM IR from the test SPICY file
3. Optionally compile and run the generated IR

---

## Project Structure

```
ast.ml         # Abstract syntax tree definitions
sast.ml        # Annotated (typed) AST
lexer.mll      # Lexer (OCamlex)
parser.mly     # Parser (Menhir)
semant.ml      # Semantic analysis (type checking)
codegen.ml     # LLVM IR generation
main.ml        # Compiler entry point
tests/         # Example programs and LLVM IR outputs
Makefile*      # Build scripts
grammar.txt    # Informal language grammar
```

---

## Running Tests

Several example SPICY programs are in the `tests/` directory. You can run all test cases with:

```sh
cd tests
./run_tests.sh
```

---

## Credits

- Built for educational purposes.
- Written in OCaml.

---

## License

**MIT License** (or specify your own)

---
