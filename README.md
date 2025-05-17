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
- **Representative Positive Examples:**
  1. **Arithmetic**
     - **Source:** 
        ```spicy
        let a = 5
        let b = a + 2 * 3
        print b
        ```
  2. **Conditional**
     - **Source:**
       ```spicy
       if true {
         print "true"
       } else {
         print "false"
       }
       ```
  3. **For Loop**
     - **Source:**
       ```spicy
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

- **Representative Negative Example:**
  - **Source:** 
    ```spicy
    let x = 1 + "94"
    print x
    ```  
  - **Expected:** the compiler should report a syntax error and exit non-zero.

- **Running the Test Suite:**
  1. Add your positive (`A.spicy`, `B.spicy`, `C.spicy`) and negative (`D.spicy`) test cases in `tests/`, along with their golden IR files (`A.ll`, `B.ll`, `C.ll`).
  2. Ensure `tests/run_tests.sh` is executable and contains the harness logic.
  3. Simply run:
     ```sh
     make test
     ```
     This will rebuild the compiler if needed and execute both positive and negative tests automatically.

- **Automation:**
  - **Unit Tests:** Shell harness (`tests/run_tests.sh`) normalizes and diffs IR, checks errors for negative case.

## Contributing
Contributions and bug reports are welcome! Please open an issue or submit a pull request with:
1. A clear description of the feature or bug
2. Steps to reproduce (for bugs)
3. Test cases (where applicable)

## License
This project is released under the MIT License.
