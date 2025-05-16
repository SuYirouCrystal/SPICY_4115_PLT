open Ast

(* SPICY base types *)
type spice_type =
  | IntType
  | BoolType
  | StringType
  | VoidType

(* Typed expressions: every node carries its inferred type *)
type sexpr = spice_type * sx
and sx =
  | SIntLit   of int
  | SBoolLit  of bool
  | SStringLit of string
  | SId       of string
  | SBinop    of sexpr * Ast.binop * sexpr
  | SUnop     of Ast.unop * sexpr
  | SFunCall  of string * sexpr list
  | SIfExpr   of sexpr * sstmt list * (sexpr * sstmt list) list * sstmt list option
  | SLoopExpr of sloop_expr
  | SParens   of sexpr

and sloop_expr =
  | SFor     of string * sexpr * sexpr * sstmt list
  | SWhile   of sexpr  * sstmt list
  | SDoWhile of sstmt list * sexpr

and sstmt =
  | SLet        of string * sexpr
  | SPrint      of sexpr
  | SFunctionDef of sfunction_def
  | SExpr       of sexpr

and sfunction_def = {
  sfname  : string;
  sparams : (string * spice_type) list;
  sbody   : sstmt list;
}

(* A typed SPICY program *)
type program = sstmt list

