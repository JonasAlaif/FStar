module FStar.PtrdiffT

module I16 = FStar.Int16

val t : eqtype

val fits (x: int) : Tot prop

val fits_lte (x y: int) : Lemma
  (requires (abs x <= abs y /\ fits y))
  (ensures (fits x))
  [SMTPat (fits x); SMTPat (fits y)]

[@@noextract_to "krml"]
val v (x: t) : Pure int
  (requires True)
  (ensures (fun y -> fits y))

val uint_to_t (x: int) : Pure t
  (requires (fits x))
  (ensures (fun y -> v y == x))

/// v and uint_to_t are inverses
val ptrdiff_v_inj (x: t)
  : Lemma
    (ensures uint_to_t (v x) == x)
    [SMTPat (v x)]

val ptrdiff_uint_to_t_inj (x: int)
  : Lemma
    (requires fits x)
    (ensures v (uint_to_t x) == x)
    [SMTPat (uint_to_t x)]

/// According to the C standard, "the bit width of ptrdiff_t is not less than 17 since c99,
/// 16 since C23"
/// (https://en.cppreference.com/w/c/types/ptrdiff_t)
/// We therefore only offer a function to create a ptrdiff_t when we are sure it fits
noextract inline_for_extraction
val mk (x: I16.t) : Pure t
  (requires True)
  (ensures (fun y -> v y == I16.v x))

noextract inline_for_extraction
let zero : (zero_ptrdiff: t { v zero_ptrdiff == 0 }) =
  mk 0s

val add (x y: t) : Pure t
  (requires (fits (v x + v y)))
  (ensures (fun z -> v z == v x + v y))

(** Modulo specification, similar to FStar.UInt.mod *)

let mod_spec (a:int{fits a}) (b:int{fits b /\ b <> 0}) : GTot (n:int{fits n}) =
  let open FStar.Mul in
  let res = a - ((a/b) * b) in
  fits_lte res b;
  res

(** Euclidean remainder

    The result is the modulus of [a] with respect to a non-zero [b] *)
val rem (a:t) (b:t{v b <> 0}) : Pure t
  (requires True)
  (ensures (fun c -> mod_spec (v a) (v b) = v c))

(** Greater than *)
val gt (x y:t) : Pure bool
  (requires True)
  (ensures (fun z -> z == (v x > v y)))

(** Greater than or equal *)
val gte (x y:t) : Pure bool
  (requires True)
  (ensures (fun z -> z == (v x >= v y)))

(** Less than *)
val lt (x y:t) : Pure bool
  (requires True)
  (ensures (fun z -> z == (v x < v y)))

(** Less than or equal *)
val lte (x y: t) : Pure bool
  (requires True)
  (ensures (fun z -> z == (v x <= v y)))

(** Infix notations *)

unfold let op_Plus_Hat = add
unfold let op_Greater_Hat = gt
unfold let op_Greater_Equals_Hat = gte
unfold let op_Less_Hat = lt
unfold let op_Less_Equals_Hat = lte
