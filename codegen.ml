(* codegen.ml: SPICY → LLVM IR *)

open Sast

(* --------------------------------------------------------------------- *)
(* Fresh name generators: registers vs. labels                           *)
(* --------------------------------------------------------------------- *)
let counter = ref 0
let fresh_reg prefix =
  let n = !counter in incr counter;
  Printf.sprintf "%%%s%d" prefix n
let fresh_lbl prefix =
  let n = !counter in incr counter;
  Printf.sprintf "%s%d" prefix n

(* --------------------------------------------------------------------- *)
(* String literal table                                                   *)
(* --------------------------------------------------------------------- *)
module Sm = Map.Make(String)
let str_tbl = ref Sm.empty
let add_string s =
  match Sm.find_opt s !str_tbl with
  | Some id -> id
  | None ->
      let id = Printf.sprintf "str%d" (Sm.cardinal !str_tbl) in
      str_tbl := Sm.add s id !str_tbl;
      id

(* --------------------------------------------------------------------- *)
(* Two‑pass string collection                                           *)
(* --------------------------------------------------------------------- *)
let rec collect_expr (_, expr) =
  match expr with
  | SStringLit s -> ignore (add_string s)
  | SBinop (e1, _, e2) -> collect_expr e1; collect_expr e2
  | SUnop (_, e) -> collect_expr e
  | SFunCall (_, args) -> List.iter collect_expr args
  | SIfExpr (c, then_b, elifs, else_b) ->
      collect_expr c;
      List.iter collect_stmt then_b;
      List.iter (fun (c2, bs) -> collect_expr c2; List.iter collect_stmt bs) elifs;
      (match else_b with Some bs -> List.iter collect_stmt bs | None -> ())
  | SLoopExpr loop ->
      (match loop with
       | SFor (_, start, stop, body) ->
           collect_expr start; collect_expr stop; List.iter collect_stmt body
       | SWhile (c, body) ->
           collect_expr c; List.iter collect_stmt body
       | SDoWhile (body, c) ->
           List.iter collect_stmt body; collect_expr c)
  | SParens e -> collect_expr e
  | _ -> ()

and collect_stmt = function
  | SLet (_, e)    -> collect_expr e
  | SPrint e       -> collect_expr e
  | SExpr  e   -> collect_expr e
  | SFunctionDef f -> List.iter collect_stmt f.sbody

let collect_strings prog = List.iter collect_stmt prog

(* --------------------------------------------------------------------- *)
(* LLVM IR header + string globals + printf formats                     *)
(* --------------------------------------------------------------------- *)
let llvm_header () =
  let str_defs =
    Sm.bindings !str_tbl
    |> List.map (fun (s,id) ->
      let len = String.length s + 1 in
      let esc = String.escaped s in
      Printf.sprintf "@%s = constant [%d x i8] c\"%s\\00\"" id len esc
    )
  in
  let fmt_defs = [
    "declare i32 @printf(i8*, ...)";
    "@.fmt_int = constant [4 x i8] c\"%d\\0A\\00\"";
    "@.fmt_str = constant [4 x i8] c\"%s\\0A\\00\""
  ] in
  str_defs @ fmt_defs

(* --------------------------------------------------------------------- *)
(* Variable environment                                                  *)
(* --------------------------------------------------------------------- *)
module StringMap = Map.Make(String)
type env = { vars: string StringMap.t }
let empty_env = { vars = StringMap.empty }
let env_add id ptr env = { vars = StringMap.add id ptr env.vars }
let env_lookup id env =
  try StringMap.find id env.vars
  with Not_found -> failwith ("Unknown variable: " ^ id)

(* --------------------------------------------------------------------- *)
(* Lower expressions (returns IR lines, result register)                *)
(* --------------------------------------------------------------------- *)
let rec code_expr env (typ, expr) =
  match expr with
  | SIntLit n ->
      ([], string_of_int n)
  | SBoolLit b ->
      ([], if b then "1" else "0")
  | SId id ->
      let ptr = env_lookup id env in
      let tmp = fresh_reg "load" in
      ([Printf.sprintf "%s = load i32, i32* %s" tmp ptr], tmp)
  | SBinop (e1, op, e2) ->
      let (c1, r1) = code_expr env e1 in
      let (c2, r2) = code_expr env e2 in
      let res = fresh_reg "bin" in
      let instr = (match op with
        | Add  -> Printf.sprintf "%s = add i32 %s, %s" res r1 r2
        | Sub  -> Printf.sprintf "%s = sub i32 %s, %s" res r1 r2
        | Mult -> Printf.sprintf "%s = mul i32 %s, %s" res r1 r2
        | Div  -> Printf.sprintf "%s = sdiv i32 %s, %s" res r1 r2
        | Eq|Neq|Lt|Gt|Le|Ge ->
            let cmpop = match op with
              | Eq  -> "eq"  | Neq -> "ne"
              | Lt  -> "slt" | Gt  -> "sgt"
              | Le  -> "sle" | Ge  -> "sge"
              | _ -> assert false
            in
            let cpr = fresh_reg "cmp" in
            let icmp = Printf.sprintf "%s = icmp %s i32 %s, %s" cpr cmpop r1 r2 in
            let zext = Printf.sprintf "%s = zext i1 %s to i32" res cpr in
            icmp ^ "\n" ^ zext
        | And  -> Printf.sprintf "%s = and i32 %s, %s" res r1 r2
        | Or   -> Printf.sprintf "%s = or i32 %s, %s" res r1 r2
      ) in
      (c1 @ c2 @ [instr], res)
  | SUnop (op, e) ->
      let (c, r) = code_expr env e in
      let res = fresh_reg "un" in
      let instr = match op with
        | Neg -> Printf.sprintf "%s = sub i32 0, %s" res r
        | Not -> Printf.sprintf "%s = xor i32 %s, 1" res r
      in (c @ [instr], res)
  | SFunCall (name, args) ->
      let crs = List.map (code_expr env) args in
      let codes = List.flatten (List.map fst crs) in
      let regs  = List.map snd crs in
      let argstr = String.concat ", " (List.map (fun r -> "i32 " ^ r) regs) in
      let res = fresh_reg "call" in
      let call = Printf.sprintf "%s = call i32 @%s(%s)" res name argstr in
      (codes @ [call], res)
  | SParens e ->
      code_expr env e
  | _ ->
      failwith "code_expr: unimplemented node"

(* --------------------------------------------------------------------- *)
(* Lower statements (returns IR lines, updated env)                     *)
(* --------------------------------------------------------------------- *)
let rec code_stmt env stmt =
  match stmt with
  | SLet (id, sexpr) ->
      let ptr   = fresh_reg "ptr" in
      let decl  = Printf.sprintf "%s = alloca i32" ptr in
      let (c, r) = code_expr env sexpr in
      let store = Printf.sprintf "store i32 %s, i32* %s" r ptr in
      (decl :: c @ [store], env_add id ptr env)

  | SPrint (StringType, SStringLit s) ->
      (* string literal → global + GEP → printf "%s\n" *)
      let gid = add_string s in
      let len = String.length s + 1 in
      let gep = fresh_reg "strptr" in
      let code_gep = Printf.sprintf
        "%s = getelementptr inbounds [%d x i8], [%d x i8]* @%s, i32 0, i32 0"
        gep len len gid
      in
      let call = Printf.sprintf
        "call i32 (i8*, ...) @printf(i8* getelementptr inbounds \
         ([4 x i8], [4 x i8]* @.fmt_str, i32 0, i32 0), i8* %s)"
        gep
      in
      ([code_gep; call], env)

  | SPrint sexpr ->
      let (c, r) = code_expr env sexpr in
      let call = Printf.sprintf
        "call i32 (i8*, ...) @printf(i8* getelementptr inbounds \
         ([4 x i8], [4 x i8]* @.fmt_int, i32 0, i32 0), i32 %s)"
        r
      in
      (c @ [call], env)

  | SExpr (_, SIfExpr (cond, then_b, elifs, else_b)) ->
      (* If/ElseIf/Else → basic blocks *)
      let then_lbl = fresh_lbl "if_then" in
      let else_lbl = fresh_lbl "if_else" in
      let end_lbl  = fresh_lbl "if_end" in

      let (cc, rc) = code_expr env cond in
      let br0 = Printf.sprintf "br i1 %s, label %%%s, label %%%s" rc then_lbl else_lbl in

      let then_code, _ = List.fold_left (fun (acc,e) st ->
        let (ls,e') = code_stmt e st in (acc @ ls, e')
      ) ([], env) then_b in

      let rec build_chain env = function
        | [] ->
            let ec,_ = match else_b with
              | Some bs -> List.fold_left (fun (acc,e) st ->
                  let (ls,e') = code_stmt e st in (acc @ ls, e')
                ) ([], env) bs
              | None -> ([], env)
            in (ec, env)
        | (c2, bs)::rest ->
            let (c2c, r2) = code_expr env c2 in
            let t2 = fresh_lbl "elif_then" in
            let e2 = if rest=[] then else_lbl else fresh_lbl "elif_else" in
            let br2 = Printf.sprintf "br i1 %s, label %%%s, label %%%s" r2 t2 e2 in
            let t2c,_ = List.fold_left (fun (acc,e) st ->
              let (ls,e') = code_stmt e st in (acc @ ls, e')
            ) ([], env) bs in
            let ec, env' = build_chain env rest in
            (c2c @ [br2; Printf.sprintf "br label %%%s" end_lbl] @ (Printf.sprintf "%s:" t2)::t2c, env')
      in
      let ec, env_after = build_chain env elifs in

      ( cc
        @ [br0; Printf.sprintf "%s:" then_lbl]
        @ then_code @ [Printf.sprintf "br label %%%s" end_lbl]
        @ [Printf.sprintf "%s:" else_lbl]
        @ ec
        @ [Printf.sprintf "br label %%%s" end_lbl;
           Printf.sprintf "%s:" end_lbl]
      , env_after )

  | SExpr (_, SLoopExpr loop) ->
      (* For/While/DoWhile → loop blocks *)
      let make_loop cond_code cond_reg body env =
        let cond_lbl = fresh_lbl "loop_cond" in
        let body_lbl = fresh_lbl "loop_body" in
        let end_lbl  = fresh_lbl "loop_end" in
        let enter    = Printf.sprintf "br label %%%s" cond_lbl in
        let decl     = Printf.sprintf "%s:" cond_lbl in
        let brc      = Printf.sprintf "br i1 %s, label %%%s, label %%%s"
                                          cond_reg body_lbl end_lbl in
        let body_code, e' = List.fold_left (fun (acc,e) st ->
          let (ls,e') = code_stmt e st in (acc @ ls, e')
        ) ([], env) body in
        let body_decl = Printf.sprintf "%s:" body_lbl in
        let back      = Printf.sprintf "br label %%%s" cond_lbl in
        let end_decl  = Printf.sprintf "%s:" end_lbl in
        ([enter; decl] @ cond_code @ [brc; body_decl]
         @ body_code @ [back; end_decl], e')
      in
      (match loop with
       | SFor (id, start, stop, body) ->
           let (c0, r0) = code_expr env start in
      let ptr       = fresh_reg "ptr" in
      let alloc_i   = Printf.sprintf "%s = alloca i32" ptr in
      let store0    = Printf.sprintf "store i32 %s, i32* %s" r0 ptr in
      let env'      = env_add id ptr env in
      let init_code = alloc_i :: (c0 @ [store0]) in

      let (c1, r1) = code_expr env' stop in

      let ld       = fresh_reg "ld" in
      let load_i   = Printf.sprintf "%s = load i32, i32* %s" ld ptr in
      let cmp      = fresh_reg "cmp" in
      let cmp_i    = Printf.sprintf "%s = icmp sle i32 %s, %s" cmp ld r1 in
      let cond_code = c1 @ [load_i; cmp_i] in

      let lc, env'' = make_loop cond_code cmp body env' in

      let br_idxs =
        lc
        |> List.mapi (fun i line ->
             if String.length line >= 9 && String.sub line 0 9 = "br label " then
               Some i
             else
               None)
        |> List.fold_left
             (fun acc -> function Some i -> i :: acc | None -> acc)
             []
      in
      let last_br = List.hd br_idxs in

      let lc' =
        lc
        |> List.mapi (fun i line ->
             if i = last_br then
               let ld2    = fresh_reg "ld" in
               let load2  = Printf.sprintf "%s = load i32, i32* %s" ld2 ptr in
               let inc    = fresh_reg "inc" in
               let add2   = Printf.sprintf "%s = add i32 %s, 1" inc ld2 in
               let store2 = Printf.sprintf "store i32 %s, i32* %s" inc ptr in
               [ load2; add2; store2; line ]
             else
               [ line ])
        |> List.flatten
      in

      ( init_code @ lc', env'' )

       | SWhile (cond, body) ->
           let (cc, rc) = code_expr env cond in
           make_loop cc rc body env

       | SDoWhile (body, cond) ->
           let bc, e' = List.fold_left (fun (acc,e) st ->
             let (ls,e') = code_stmt e st in (acc @ ls, e')
           ) ([], env) body in
           let (cc, rc) = code_expr e' cond in
           let lc, e'' = make_loop [] rc body e' in
           (bc @ lc, e'')
      )

  | SExpr sexpr ->
      let (c, _) = code_expr env sexpr in
      (c, env)

  | SFunctionDef _ ->
      failwith "code_stmt: SFunctionDef only at top-level"

(* --------------------------------------------------------------------- *)
(* Lower a SPICY function → LLVM IR                                       *)
(* --------------------------------------------------------------------- *)
let translate_function fd =
  let header = Printf.sprintf "define i32 @%s(%s) {" fd.sfname
      (String.concat ", " (List.map (fun (n,_) -> "i32 %" ^ n) fd.sparams))
  in
  let env, allocs = List.fold_left (fun (env, acc) (n,_) ->
    let ptr   = fresh_reg "ptr" in
    let a     = Printf.sprintf "  %s = alloca i32" ptr in
    let s     = Printf.sprintf "  store i32 %%%s, i32* %s" n ptr in
    (env_add n ptr env, acc @ [a; s])
  ) (empty_env, []) fd.sparams in

  let body_ir, env' = List.fold_left (fun (acc,e) stmt ->
    let (ls,e') = code_stmt e stmt in
    (acc @ List.map (fun l->"  "^l) ls, e')
  ) ([], env) fd.sbody in

  let ret_instr =
    match List.rev fd.sbody with
    | SExpr _ :: _ ->
        (* 找到 body_ir 中最后一条非空行 *)
        let last_line =
          body_ir
          |> List.filter (fun s -> String.trim s <> "")
          |> List.rev
          |> List.hd
        in
        (* 去掉前两格空格，然后取第一个 token（寄存器名） *)
        let inst = String.trim last_line in
        let reg =
          try String.sub inst 0 (String.index inst ' ')
          with _ -> "0"
        in
        Printf.sprintf "  ret i32 %s" reg
    | _ ->
        "  ret i32 0"
  in

  String.concat "\n"
    ( [header]
    @ allocs
    @ body_ir
    @ [ ret_instr; "}" ] )

(* --------------------------------------------------------------------- *)
(* Top-level: collect strings, emit header, all funcs, then main wrapper *)
(* --------------------------------------------------------------------- *)
let translate_program prog =
  collect_strings prog;
  let header = llvm_header () in
  let funcs, tops = List.partition (function SFunctionDef _ -> true | _ -> false) prog in
  let func_ir = List.map (function SFunctionDef fd -> translate_function fd | _ -> assert false) funcs in
  let main_body, _ = List.fold_left (fun (acc,e) stmt ->
    let (ls,e') = code_stmt e stmt in
    (acc @ List.map (fun l->"  "^l) ls, e')
  ) ([], empty_env) tops in
  String.concat "\n"
    ( header
    @ func_ir
    @ ["define i32 @main() {"]
    @ main_body
    @ ["  ret i32 0"; "}"] )

