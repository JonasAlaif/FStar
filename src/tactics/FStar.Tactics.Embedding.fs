﻿#light "off"
module FStar.Tactics.Embedding
open FStar
open FStar.All
open FStar.Syntax.Syntax
open FStar.Util

module S = FStar.Syntax.Syntax
module SS = FStar.Syntax.Subst
module SC = FStar.Syntax.Const
module Env = FStar.TypeChecker.Env
module BU = FStar.Util
module U = FStar.Syntax.Util
module Rel = FStar.TypeChecker.Rel
module Print = FStar.Syntax.Print
module TcUtil = FStar.TypeChecker.Util
module N = FStar.TypeChecker.Normalize
open FStar.Tactics.Basic
module Core = FStar.Tactics.Basic
type name = bv



let fstar_tactics_lid s = Ident.lid_of_path (["FStar"; "Tactics"]@[s]) Range.dummyRange
let by_tactic_lid = fstar_tactics_lid "by_tactic"
let lid_as_tm l = S.lid_as_fv l Delta_constant None |> S.fv_to_tm
let mk_tactic_lid_as_term (s:string) = lid_as_tm (fstar_tactics_lid s)
let fstar_tactics_term   = mk_tactic_lid_as_term "term"
let fstar_tactics_env    = mk_tactic_lid_as_term "env"
let fstar_tactics_binder = mk_tactic_lid_as_term "binder"
let fstar_tactics_binders= mk_tactic_lid_as_term "binders"
let fstar_tactics_goal   = mk_tactic_lid_as_term "goal"
let fstar_tactics_goals  = mk_tactic_lid_as_term "goals"
let fstar_tactics_formula  = mk_tactic_lid_as_term "formula"

let lid_as_data_tm l = S.fv_to_tm (S.lid_as_fv l Delta_constant (Some Data_ctor))
let fstar_tactics_lid_as_data_tm s = lid_as_data_tm (fstar_tactics_lid s)
let fstar_tactics_Failed = fstar_tactics_lid_as_data_tm "Failed"
let fstar_tactics_Success= fstar_tactics_lid_as_data_tm "Success"
let fstar_tactics_True_ = fstar_tactics_lid_as_data_tm "True_"
let fstar_tactics_False_ = fstar_tactics_lid_as_data_tm "False_"
let fstar_tactics_Eq = fstar_tactics_lid_as_data_tm "Eq"
let fstar_tactics_And = fstar_tactics_lid_as_data_tm "And"
let fstar_tactics_Or = fstar_tactics_lid_as_data_tm "Or"
let fstar_tactics_Not = fstar_tactics_lid_as_data_tm "Not"
let fstar_tactics_Implies = fstar_tactics_lid_as_data_tm "Implies"
let fstar_tactics_Iff = fstar_tactics_lid_as_data_tm "Iff"
let fstar_tactics_Forall = fstar_tactics_lid_as_data_tm "Forall"
let fstar_tactics_Exists = fstar_tactics_lid_as_data_tm "Exists"

let lid_Mktuple2 = U.mk_tuple_data_lid 2 Range.dummyRange
exception Unembed_failed of string
let embed_binder (b:binder) : term = S.bv_to_name (fst b)
let unembed_binder (t:term) : binder =
    let t = U.unascribe t in
    match t.n with
    | Tm_name bv -> S.mk_binder bv
    | _ -> failwith "Not an embedded binder"

let embed_pair (x:('a * 'b)) (embed_a:'a -> term) (t_a:term) (embed_b:'b -> term) (t_b:term) : term =
    S.mk_Tm_app (S.mk_Tm_uinst (lid_as_data_tm lid_Mktuple2) [U_zero;U_zero])
                [S.iarg t_a;
                 S.iarg t_b;
                 S.as_arg (embed_a (fst x));
                 S.as_arg (embed_b (snd x))]
                None
                Range.dummyRange

let unembed_pair (pair:term) (unembed_a:term -> 'a) (unembed_b:term -> 'b) : ('a * 'b) =
    let pairs = U.unascribe pair in
    let hd, args = U.head_and_args pair in
    match (U.un_uinst hd).n, args with
    | Tm_fvar fv, [_; _; (a, _); (b, _)] when S.fv_eq_lid fv lid_Mktuple2 ->
      unembed_a a, unembed_b b
    | _ -> failwith "Not an embedded pair"

let embed_option (embed_a:'a -> term) (typ:term) (o:option<'a>) : term =
    match o with
    | None ->
      S.mk_Tm_app (S.mk_Tm_uinst (lid_as_data_tm SC.none_lid) [U_zero])
                  [S.iarg typ]
                  None Range.dummyRange
    | Some a ->
      S.mk_Tm_app (S.mk_Tm_uinst (lid_as_data_tm SC.some_lid) [U_zero])
                  [S.iarg typ; S.as_arg (embed_a a)]
                  None Range.dummyRange

let unembed_option (unembed_a:term -> 'a) (o:term) : option<'a> =
   let hd, args = U.head_and_args o in
   match (U.un_uinst hd).n, args with
   | Tm_fvar fv, _ when S.fv_eq_lid fv SC.none_lid -> None
   | Tm_fvar fv, [_; (a, _)] when S.fv_eq_lid fv SC.some_lid ->
     Some (unembed_a a)
   | _ -> failwith "Not an embedded option"

let rec embed_list (l:list<'a>) (embed_a: ('a -> term)) (t_a:term) : term =
    match l with
    | [] -> S.mk_Tm_app (S.mk_Tm_uinst (lid_as_data_tm FStar.Syntax.Const.nil_lid) [U_zero])
                        [S.iarg t_a]
                        None
                        Range.dummyRange
    | hd::tl ->
            S.mk_Tm_app (S.mk_Tm_uinst (lid_as_data_tm FStar.Syntax.Const.cons_lid) [U_zero])
                        [S.iarg t_a;
                         S.as_arg (embed_a hd);
                         S.as_arg (embed_list tl embed_a t_a)]
                        None
                        Range.dummyRange

let rec unembed_list (l:term) (unembed_a: (term -> 'a)) : list<'a> =
    let l = U.unascribe l in
    let hd, args = U.head_and_args l in
    match (U.un_uinst hd).n, args with
    | Tm_fvar fv, _
        when S.fv_eq_lid fv SC.nil_lid -> []

    | Tm_fvar fv, [_t; (hd, _); (tl, _)]
        when S.fv_eq_lid fv SC.cons_lid ->
      unembed_a hd :: unembed_list tl unembed_a

    | _ ->
      failwith (BU.format1 "Not an embedded list: %s" (Print.term_to_string l))

let embed_binders l = embed_list l embed_binder fstar_tactics_binder
let unembed_binders t = unembed_list t unembed_binder

let embed_env (env:Env.env) : term =
    embed_list (Env.all_binders env) embed_binder fstar_tactics_binder

let unembed_env (env:Env.env) (embedded_env:term) : Env.env =
    let binders = unembed_list embedded_env unembed_binder in
    printfn "Unembedding environment: %s" (Print.binders_to_string ", " binders);
    List.fold_left (fun env b ->
        match Env.try_lookup_bv env (fst b) with
        | None -> Env.push_binders env [b]
        | _ -> env) env binders

let embed_goal (g:goal) : term =
    embed_pair (g.context, g.goal_ty) embed_env fstar_tactics_env (fun x -> x) fstar_tactics_term

let unembed_goal (env:Env.env) (t:term) : goal =
    let env, goal_ty = unembed_pair t (unembed_env env) (fun x -> x) in
    {
      context = env;
      goal_ty = goal_ty;
      witness = None //TODO: sort this out for proof-relevant goals
    }

let embed_term (t:term) : term = t
let unembed_term (t:term) : term = t

let embed_goals (l:list<goal>) : term = embed_list l embed_goal fstar_tactics_goal
let unembed_goals (env:Env.env) (egs:term) : list<goal> = unembed_list egs (unembed_goal env)

type state = list<goal> * list<goal>

let embed_state (s:state) : term =
    embed_pair s embed_goals fstar_tactics_goals embed_goals fstar_tactics_goals

let unembed_state (env:Env.env) (s:term) : state =
    let s = U.unascribe s in
    unembed_pair s (unembed_goals env) (unembed_goals env)

let embed_unit (u:unit) : term = SC.exp_unit
let unembed_unit (_:term) :unit = ()

let embed_string (s:string) : term =
    let bytes = BU.unicode_of_string s in
    S.mk (Tm_constant(FStar.Const.Const_string(bytes, Range.dummyRange)))
         None
         Range.dummyRange

let unembed_string (t:term) : string =
    let t = U.unascribe t in
    match t.n with
    | Tm_constant(FStar.Const.Const_string(bytes, _)) ->
      BU.string_of_unicode bytes
    | _ ->
      failwith "Not an embedded string"

let embed_result (res:result<'a>) (embed_a:'a -> term) (t_a:typ) : term =
    match res with
    | Failed (msg, ps) ->
      S.mk_Tm_app (S.mk_Tm_uinst fstar_tactics_Failed [U_zero])
                  [S.iarg t_a;
                   S.as_arg (embed_string msg);
                   S.as_arg (embed_state (ps.goals, ps.smt_goals))]
                  None
                  Range.dummyRange
    | Success (a, ps) ->
      S.mk_Tm_app (S.mk_Tm_uinst fstar_tactics_Success [U_zero])
                  [S.iarg t_a;
                   S.as_arg (embed_a a);
                   S.as_arg (embed_state (ps.goals, ps.smt_goals))]
                  None
                  Range.dummyRange

let unembed_result (env:Env.env) (res:term) (unembed_a:term -> 'a) : either<('a * state), (string * state)> =
    let res = U.unascribe res in
    let hd, args = U.head_and_args res in
    match (U.un_uinst hd).n, args with
    | Tm_fvar fv, [_t; (a, _); (embedded_state, _)]
        when S.fv_eq_lid fv (fstar_tactics_lid "Success") ->
      Inl (unembed_a a, unembed_state env embedded_state)

    | Tm_fvar fv, [_t; (embedded_string, _); (embedded_state, _)]
        when S.fv_eq_lid fv (fstar_tactics_lid "Failed") ->
      Inr (unembed_string embedded_string, unembed_state env embedded_state)

    | _ -> failwith (BU.format1 "Not an embedded result: %s" (Print.term_to_string res))


let embed_formula (f:U.connective) : term =
    let encode_app (l:Ident.lid) (args:args) : term =
        let hd =
            if Ident.lid_equals l SC.true_lid then fstar_tactics_True_
            else if Ident.lid_equals l SC.false_lid then fstar_tactics_False_
            else if Ident.lid_equals l SC.and_lid then fstar_tactics_And
            else if Ident.lid_equals l SC.or_lid then fstar_tactics_Or
            else if Ident.lid_equals l SC.not_lid then fstar_tactics_Not
            else if Ident.lid_equals l SC.imp_lid then fstar_tactics_Implies
            else if Ident.lid_equals l SC.iff_lid then fstar_tactics_Iff
            else if Ident.lid_equals l SC.eq2_lid then fstar_tactics_Eq
            else failwith ("Unrecognized connective" ^ (Ident.string_of_lid l)) in
        match args with
        | [] -> hd
        | _ -> S.mk_Tm_app hd args None Range.dummyRange
    in
    match f with
    | U.QAll(binders, qpats, typ) -> //patterns are not encoded to a user tactic; TODO, fix?
      S.mk_Tm_app fstar_tactics_Forall
                  [S.as_arg (embed_binders binders);
                   S.as_arg (embed_term typ)]
                  None
                  Range.dummyRange

    | U.QEx(binders, qpats, typ) -> //patterns are not encoded to a user tactic; TODO, fix?
      S.mk_Tm_app fstar_tactics_Exists
                  [S.as_arg (embed_binders binders);
                   S.as_arg (embed_term typ)]
                  None
                  Range.dummyRange

    | U.BaseConn(lid, args) ->
      encode_app lid args

let unembed_formula (f:term) : U.connective =
    let hd, args = U.head_and_args f in
    let fv_eq_tm fv tm =
        match tm.n with
        | Tm_fvar fv' -> S.fv_eq fv fv'
        | _ -> false
   in
    match (SS.compress hd).n, args with
    | Tm_fvar fv, [(binders, _); (tm, _)]
        when fv_eq_tm fv fstar_tactics_Forall ->
      U.QAll (unembed_binders binders, [], unembed_term tm) //TODO: restore patterns

    | Tm_fvar fv, [(binders, _); (tm, _)]
        when fv_eq_tm fv fstar_tactics_Exists ->
      U.QEx (unembed_binders binders, [], unembed_term tm) //TODO: restore patterns

    | Tm_fvar fv, _ ->
      let lid =
        if fv_eq_tm fv fstar_tactics_True_ then SC.true_lid
        else if fv_eq_tm fv fstar_tactics_False_ then SC.false_lid
        else if fv_eq_tm fv fstar_tactics_And then SC.and_lid
        else if fv_eq_tm fv fstar_tactics_Or then SC.or_lid
        else if fv_eq_tm fv fstar_tactics_Not then SC.not_lid
        else if fv_eq_tm fv fstar_tactics_Implies then SC.imp_lid
        else if fv_eq_tm fv fstar_tactics_Iff then SC.iff_lid
        else if fv_eq_tm fv fstar_tactics_Eq then SC.eq2_lid
        else failwith ("Unrecognized connective" ^ (Ident.string_of_lid fv.fv_name.v)) in
     U.BaseConn(lid, args)

    | _ -> failwith "Not an embedded formula"

