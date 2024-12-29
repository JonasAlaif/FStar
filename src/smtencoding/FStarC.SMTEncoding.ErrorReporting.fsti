﻿(*
   Copyright 2008-2014 Nikhil Swamy and Microsoft Research

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

module FStarC.SMTEncoding.ErrorReporting
open FStarC.Compiler.Effect
open FStar open FStarC
open FStarC.Compiler
open FStarC.BaseTypes
open FStarC.Compiler.Util
open FStarC.SMTEncoding.Term
open FStarC.SMTEncoding.Util
open FStarC.SMTEncoding
open FStarC.Compiler.Range
module BU = FStarC.Compiler.Util

type label = error_label
type labels = list label

val label_goals : option (unit -> string) -> range -> q:term -> labels & term

val detail_errors :  bool //detail_hint_replay?
                  -> TypeChecker.Env.env
                  -> labels
                  -> (list decl -> Z3.z3result)
                  -> unit