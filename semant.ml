open Ast
open Sast

module StringMap = Map.Make(String)

exception SemanticError of string

let err fmt = Printf.ksprintf (fun s -> raise (SemanticError s)) fmt

(* Decision: all SPICY functions return VoidType, params default to IntType *)
let build_func_env (prog : Ast.program) : (spice_type list * spice_type) StringMap.t =
  List.fold_left (fun env stmt ->
    match stmt with
    | Ast.FunctionDef fd ->
        let param_ts = List.map (fun _ -> IntType) fd.params in
        StringMap.add fd.fname (param_ts, VoidType) env
    | _ -> env
  ) StringMap.empty prog

(* Type-check expressions *)
let rec check_expr (fenv : (spice_type list * spice_type) StringMap.t)
                   (venv : spice_type StringMap.t)
                   (e : Ast.expr) : sexpr =
  match e with
  | Ast.IntLit n        -> (IntType, SIntLit n)
  | Ast.BoolLit b       -> (BoolType, SBoolLit b)
  | Ast.StringLit s     -> (StringType, SStringLit s)
  | Ast.Id id           ->
      (match StringMap.find_opt id venv with
       | Some t -> (t, SId id)
       | None   -> err "Undefined variable '%s'" id)

  | Ast.Binop (e1, op, e2) ->
      let (t1,se1) = check_expr fenv venv e1 in
      let (t2,se2) = check_expr fenv venv e2 in
      (match op, t1, t2 with
       | (Add|Sub|Mult|Div), IntType, IntType -> (IntType, SBinop((t1,se1),op,(t2,se2)))
       | (Eq|Neq|Lt|Gt|Le|Ge), IntType, IntType -> (BoolType, SBinop((t1,se1),op,(t2,se2)))
       | (And|Or), BoolType, BoolType      -> (BoolType, SBinop((t1,se1),op,(t2,se2)))
       | _ -> err "Type error in binary operator")

  | Ast.Unop (u, e) ->
      let (t,se) = check_expr fenv venv e in
      (match u, t with
       | Neg, IntType  -> (IntType, SUnop(u,(t,se)))
       | Not, BoolType -> (BoolType, SUnop(u,(t,se)))
       | _ -> err "Type error in unary operator")

  | Ast.FunCall (name, args) ->
      let (param_ts, ret_t) =
        match StringMap.find_opt name fenv with
        | Some sig_ -> sig_
        | None      -> err "Undefined function '%s'" name
      in
      let checked_args = List.map (check_expr fenv venv) args in
      let arg_ts = List.map fst checked_args in
      if List.length arg_ts <> List.length param_ts then
        err "Function '%s' expects %d args but got %d" name
          (List.length param_ts) (List.length arg_ts);
      List.iter2 (fun expected got ->
        if expected <> got then err "Type mismatch in function '%s'" name
      ) param_ts arg_ts;
      (ret_t, SFunCall(name, checked_args))

  | Ast.IfExpr (cond, then_b, elifs, else_b) ->
      let se_cond = check_expr fenv venv cond in
      if fst se_cond <> BoolType then err "If condition must be boolean";
      let sthen = check_stmt_list fenv venv then_b in
      let selifs = List.map (fun (e,stmts) ->
        let se = check_expr fenv venv e in
        if fst se <> BoolType then err "Elif condition must be boolean";
        (se, check_stmt_list fenv venv stmts)
      ) elifs in
      let selse = Option.map (check_stmt_list fenv venv) else_b in
      (VoidType, SIfExpr(se_cond, sthen, selifs, selse))

  | Ast.LoopExpr loop ->
      (match loop with
       | For (id, start, stop, body) ->
           let se_start = check_expr fenv venv start in
           let se_stop  = check_expr fenv venv stop  in
           if fst se_start<>IntType || fst se_stop<>IntType then
             err "For bounds must be Int";
           let venv' = StringMap.add id IntType venv in
           let sbody = check_stmt_list fenv venv' body in
           (VoidType, SLoopExpr(SFor(id,se_start,se_stop,sbody)))

       | While (cond, body) ->
           let se = check_expr fenv venv cond in
           if fst se<>BoolType then err "While condition must be Bool";
           (VoidType, SLoopExpr(SWhile(se,check_stmt_list fenv venv body)))

       | DoWhile (body, cond) ->
           let se = check_expr fenv venv cond in
           if fst se<>BoolType then err "DoWhile condition must be Bool";
           (VoidType, SLoopExpr(SDoWhile(check_stmt_list fenv venv body,se)))
      )

  | Ast.Parens e ->
      let se = check_expr fenv venv e in
      (fst se, SParens se)

(* Type-check statements *)
and check_stmt fenv venv = function
  | Ast.Let (id,e) ->
      let se = check_expr fenv venv e in
      SLet(id,se)

  | Ast.Print e ->
      let se = check_expr fenv venv e in
      SPrint(se)

  | Ast.FunctionDef fd ->
      let venv' = List.fold_left (fun m p -> StringMap.add p IntType m) venv fd.params in
      let sbody = check_stmt_list fenv venv' fd.body in
      SFunctionDef { sfname=fd.fname; sparams=List.map (fun p -> (p,IntType)) fd.params; sbody }

  | Ast.Expr e ->
      let se = check_expr fenv venv e in
      SExpr se

(* Type-check a list of statements, accumulating new lets *)
and check_stmt_list fenv venv stmts =
  let rec aux env acc = function
    | [] -> List.rev acc
    | s::ss ->
        let s' = check_stmt fenv env s in
        let env' = match s' with
          | SLet(id,se) -> StringMap.add id (fst se) env
          | _ -> env
        in
        aux env' (s'::acc) ss
  in aux venv [] stmts

(* Entry point for semantic analysis *)
let check_program prog =
  let fenv = build_func_env prog in
  check_stmt_list fenv StringMap.empty prog

