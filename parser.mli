
(* The type of tokens. *)

type token = 
  | WHILE
  | VOID_TYPE
  | TIMES
  | STRING_TYPE
  | STRING of (string)
  | RPAREN
  | RETURN
  | RBRACE
  | PRINT
  | PLUS
  | OR
  | NOT
  | NEWLINE
  | NEQ
  | MINUS
  | LT
  | LPAREN
  | LET
  | LE
  | LBRACE
  | INT_TYPE
  | INT of (int)
  | IN
  | IF
  | IDENTIFIER of (string)
  | GT
  | GE
  | FUN
  | FOR
  | EQ
  | EOF
  | ELSEIF
  | ELSE
  | DOTDOT
  | DO
  | DIVIDE
  | COMMA
  | BOOL_TYPE
  | BOOLEAN_LITERAL of (bool)
  | ASSIGN
  | AND

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val program: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Ast.program)
