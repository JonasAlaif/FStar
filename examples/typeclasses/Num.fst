(*
   Copyright 2008-2018 Microsoft Research

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
module Num

open FStar.Tactics.Typeclasses
open Eq
open Add

(* Numeric class, including superclasses for decidable equality
 * and a monoid, extended with a minus operation. *)
class num a = {
    eq_super  : deq a;
    add_super : additive a;
    minus     : a -> a -> a;
}

(* These methods are generated by the splice *)
(* [@@tcnorm] let minus (#a:Type) {|d : num a|} = d.minus *)

(* Superclass projectors! Should also be autogenerated. Note the `instance` attribute,
 * differently from the methods, since these participate in the search. *)
instance num_eq  (d : num 'a) : deq 'a = d.eq_super
instance add_num (d : num 'a) : additive 'a = d.add_super

let mknum (#a:Type) {|deq a|} {|additive a|} (f : a -> a -> a) : num a =
  { eq_super  = solve;
    add_super = solve;
    minus     = f; }

instance num_int : num int = mknum (fun x y -> x - y)

instance num_bool : num bool = mknum (fun x y -> x && not y)
