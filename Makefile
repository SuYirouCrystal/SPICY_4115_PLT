# Makefile for SPICY Compiler in pure MinGW64 environment

# Tools
OCAMLC      = ocamlc.opt
MENHIR      = menhir
LEX         = ocamllex
LLC         = llc
CC          = gcc
SRC         = test2.spicy
IR          = program.ll
BIN         = test2

.PHONY: all spicyc ir run clean

# Default: build compiler, emit IR, then run
all: run

# 1) Build the SPICY compiler frontend (bytecode)
spicyc: ast.cmo parser.cmi sast.cmo semant.cmo codegen.cmo parser.cmo lexer.cmo main.cmo
	$(OCAMLC) -o spicyc.exe ast.cmo sast.cmo semant.cmo codegen.cmo parser.cmo lexer.cmo main.cmo

# 1a) Compile ast.ml to produce ast.cmi & ast.cmo
ast.cmo: ast.ml
	$(OCAMLC) -c ast.ml

# 1b) Generate parser.ml + parser.mli from grammar
parser.ml parser.mli: parser.mly
	$(MENHIR) --ocamlc $(OCAMLC) --infer parser.mly

# 1c) Compile interface to .cmi, depends on ast.cmo (Ast module)
parser.cmi: parser.mli ast.cmo
	$(OCAMLC) -c parser.mli

# 1d) Compile parser.ml to .cmo
parser.cmo: parser.ml parser.cmi
	$(OCAMLC) -c parser.ml

# 1e) Generate and compile lexer
lexer.ml: lexer.mll parser.cmi
	$(LEX) lexer.mll
lexer.cmo: lexer.ml parser.cmi
	$(OCAMLC) -c lexer.ml

# 1f) Compile other modules
sast.cmo: sast.ml
	$(OCAMLC) -c sast.ml
semant.cmo: semant.ml
	$(OCAMLC) -c semant.ml
codegen.cmo: codegen.ml
	$(OCAMLC) -c codegen.ml
main.cmo: main.ml
	$(OCAMLC) -c main.ml

# 2) Emit LLVM IR from SPICY source
ir: spicyc
	./spicyc.exe $(SRC) > $(IR)

# 3) Compile IR to object and link with gcc, then run
run: ir
	$(LLC) -filetype=obj $(IR) -o program.o
	$(CC) program.o -o $(BIN).exe
	./$(BIN).exe

# Clean up artifacts
clean:
	rm -f *.cmo *.cmi spicyc.exe program.ll program.o $(BIN).exe
