# SPICY - COMS 4115 Programming Language and Translators Final Project

A minimal compiler for the SPICY programming language, implemented in OCaml.

## Features

- **Lexical analysis** with OCaml’s `ocamllex`
- **Parsing** via Menhir (`.mly` grammar)
- **Abstract Syntax Tree (AST)** construction
- **Semantic Analysis** (type checking, name resolution)
- **Code Generation** to a target intermediate representation
- **Command-line driver** for compilation and testing

## Prerequisites

- [OCaml](https://ocaml.org/) (version ≥ 4.12.0)
- [Menhir](https://github.com/ocaml/menhir)
- `ocamllex` (bundled with OCaml)
- GNU Make (or compatible)
> **Windows users:** Install the full LLVM toolchain (e.g., from `clang+llvm-<version>-x86_64-pc-windows-msvc.tar.xz`) so that `clang`, `llc`, `lli`, and other LLVM utilities are available on `PATH`.

You can install the OCaml toolchain via OPAM:

```sh
opam install ocaml menhir dune
```

## Building
From the project root:
```sh
make
```

On macOS:
```sh
make -f Makefile_mac
```

On Windows (MinGW64):
```sh
make -f Makefile_win_mingw64
```
This will produce the compiler executable `spicyc` (and on Windows, `test.exe`).

## Usage
Compile a SPICY source file (`.spicy`) into assembly or run it directly:
```sh
# Generate assembly (e.g. .s file)
./spicyc example.spicy -o example.s

# Compile and run via built-in harness
./spicyc example.spicy
```

You can also pass `-help` to see all available options:
```sh
./spicyc -help
```

## Testing
A basic test suite is included in the tests/ directory (if present). To run tests:
```sh
make # Test file alreading present
```

## Contributing
Contributions and bug reports are welcome! Please open an issue or submit a pull request with:
1. A clear description of the feature or bug
2. Steps to reproduce (for bugs)
3. Test cases (where applicable)

## License
This project is released under the MIT License.
