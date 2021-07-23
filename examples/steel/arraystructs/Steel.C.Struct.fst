module Steel.C.Struct

module P = FStar.PCM
open Steel.C.PCM
open Steel.C.Connection
open Steel.C.Ref
module Ptr = Steel.C.Ptr
open Steel.Effect
module A = Steel.Effect.Atomic

(** A PCM for structs *)

/// We can generalize to 'a-ary products (k:'a -> 'b k), given a PCM for each k:

open FStar.FunctionalExtensionality
open FStar.Classical
let ext (f g: restricted_t 'a 'b) (fg:(x:'a -> Lemma (f x == g x))) : Lemma (f == g) =
  extensionality 'a 'b f g;
  forall_intro fg

let prod_comp (p:(k:'a -> pcm ('b k))) (x y: restricted_t 'a 'b): prop =
  forall k. composable (p k) (x k) (y k)

let prod_op (p:(k:'a -> pcm ('b k)))
  (x: restricted_t 'a 'b) (y: restricted_t 'a 'b{prod_comp p x y})
: restricted_t 'a 'b
= on_domain 'a (fun k -> op (p k) (x k) (y k) <: 'b k)

let prod_one (p:(k:'a -> pcm ('b k))): restricted_t 'a 'b =
  on_domain 'a (fun k -> one (p k))

let prod_comm (p:(k:'a -> pcm ('b k)))
  (x: restricted_t 'a 'b) (y: restricted_t 'a 'b{prod_comp p x y})
: Lemma (prod_op p x y == prod_op p y x)
= ext (prod_op p x y) (prod_op p y x) (fun k -> ())

let prod_assoc (p:(k:'a -> pcm ('b k)))
  (x y: restricted_t 'a 'b)
  (z: restricted_t 'a 'b{prod_comp p y z /\ prod_comp p x (prod_op p y z)})
: Lemma (prod_comp p x y /\
         prod_comp p (prod_op p x y) z /\
         prod_op p x (prod_op p y z) == prod_op p (prod_op p x y) z)
= let aux k
  : Lemma (composable (p k) (x k) (y k) /\
           composable (p k) (op (p k) (x k) (y k)) (z k)) 
    [SMTPat (p k)]
  = ()
  in
  ext (prod_op p x (prod_op p y z)) (prod_op p (prod_op p x y) z)
    (fun k -> ())

let prod_assoc_r (p:(k:'a -> pcm ('b k)))
  (x y: restricted_t 'a 'b)
  (z: restricted_t 'a 'b{prod_comp p x y /\ prod_comp p (prod_op p x y) z})
: Lemma (prod_comp p y z /\
         prod_comp p x (prod_op p y z) /\
         prod_op p x (prod_op p y z) == prod_op p (prod_op p x y) z)
= let aux k
  : Lemma (composable (p k) (y k) (z k) /\
           composable (p k) (x k) (op (p k) (y k) (z k)))
    [SMTPat (p k)]
  = ()
  in
  ext (prod_op p x (prod_op p y z)) (prod_op p (prod_op p x y) z)
    (fun k -> ())

let prod_is_unit (p:(k:'a -> pcm ('b k))) (x: restricted_t 'a 'b)
: Lemma (prod_comp p x (prod_one p) /\
         prod_op p x (prod_one p) == x)
= let is_unit k
  : Lemma (composable (p k) (x k) (prod_one p k))
    [SMTPat (p k)]
  = ()
  in ext (prod_op p x (prod_one p)) x (fun k -> ())

let prod_refine (p:(k:'a -> pcm ('b k))) (x: restricted_t 'a 'b): prop =
  (exists (k: 'a). True) /\ (forall k. p_refine (p k) (x k))

let fstar_prod_pcm (p:(k:'a -> pcm ('b k))): P.pcm (restricted_t 'a 'b) = let open P in {
  comm = prod_comm p;
  p = {composable = prod_comp p; op = prod_op p; one = prod_one p};
  assoc = prod_assoc p;
  assoc_r = prod_assoc_r p;
  is_unit = prod_is_unit p;
  refine = prod_refine p
}

let prod_pcm' (p:(k:'a -> pcm ('b k))): pcm0 (restricted_t 'a 'b) = pcm_of_fstar_pcm (fstar_prod_pcm p)

let prod_pcm (p:(k:'a -> pcm ('b k))): pcm (restricted_t 'a 'b) =
  let p' = prod_pcm' p in
  assert (forall x y . (composable p' x y /\ op p' x y == one p') ==> (
    x `feq` one p' /\ y `feq` one p'
  ));
  assert (forall x frame . (prod_refine p x /\ prod_comp p x frame) ==> frame `feq` prod_one p);
  prod_pcm' p

let prod_pcm_composable_intro0
  (p:(k:'a -> pcm ('b k)))
  (x y: restricted_t 'a 'b)
: Lemma
  ((composable (prod_pcm p) x y <==> prod_comp p x y) /\
  (composable (prod_pcm p) x y ==> op (prod_pcm p) x y == prod_op p x y))
  [SMTPat (composable (prod_pcm p) x y)]
= ()

let prod_pcm_composable_intro (p:(k:'a -> pcm ('b k))) (x y: restricted_t 'a 'b)
  (h:(k:'a -> Lemma (composable (p k) (x k) (y k))))
: Lemma (composable (prod_pcm p) x y) = FStar.Classical.forall_intro h

let field_to_struct_f
  (#a: eqtype)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
  (x: b k)
: Pure (restricted_t a b)
  (requires True)
  (ensures (fun y -> forall k' . y k' == (if k' = k then (x <: b k') else one (p k'))))
= on_dom a (fun k' -> if k' = k then (x <: b k') else one (p k'))

let field_to_struct
  (#a: eqtype)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
: Tot (morphism (p k) (prod_pcm p))
= mkmorphism
    (field_to_struct_f p k)
    (assert (field_to_struct_f p k (one (p k)) `feq` one (prod_pcm p)))
    (fun x1 x2 ->
      Classical.forall_intro_2 (fun k -> is_unit (p k));
      assert (prod_op p (field_to_struct_f p k x1) (field_to_struct_f p k x2) `feq` field_to_struct_f p k (op (p k) x1 x2));
        ())

let struct_to_field_f
  (#a: Type)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
  (x: restricted_t a b)
: Tot (b k)
= x k

let struct_to_field
  (#a: Type)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
: Tot (morphism (prod_pcm p) (p k))
= mkmorphism
    (struct_to_field_f p k) ()
    (fun x1 x2 -> ())

let struct_field_lift_fpu'
  (#a: eqtype)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
  (x: Ghost.erased (b k) { ~ (Ghost.reveal x == one (p k)) })
  (y: Ghost.erased (b k))
  (f: frame_preserving_upd (p k) x y)
  (v: restricted_t a b {
    p_refine (prod_pcm p) v /\
    compatible (prod_pcm p) ((field_to_struct p k).morph x) v
  })
: Tot (restricted_t a b)
= 
    on_dom a (fun k' ->
      if k' = k
      then f (v k) <: b k'
      else v k'
    )

#push-options "--query_stats --z3rlimit 30"
#restart-solver

let struct_field_lift_fpu_prf
  (#a: eqtype)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
  (x: Ghost.erased (b k) { ~ (Ghost.reveal x == one (p k)) })
  (y: Ghost.erased (b k))
  (f: frame_preserving_upd (p k) x y)
  (v: restricted_t a b {
    p_refine (prod_pcm p) v /\
    compatible (prod_pcm p) ((field_to_struct p k).morph x) v
  })
: Lemma
  (let v_new = struct_field_lift_fpu' p k x y f v in
    p_refine (prod_pcm p) v_new /\
    compatible (prod_pcm p) ((field_to_struct p k).morph y) v_new /\
    (forall (frame:_{composable (prod_pcm p) ((field_to_struct p k).morph x) frame}).
       composable (prod_pcm p) ((field_to_struct p k).morph y) frame /\
       (op (prod_pcm p) ((field_to_struct p k).morph x) frame == v ==> op (prod_pcm p) ((field_to_struct p k).morph y) frame == v_new))
  )
=
  let y' = (field_to_struct p k).morph y in
  let v_new = struct_field_lift_fpu' p k x y f v in
  Classical.forall_intro_2 (fun k -> is_unit (p k));
  assert (forall (frame: b k) .
    (composable (p k) y frame /\ op (p k) frame y == f (v k)) ==> (
    let frame' : restricted_t a b = on_dom a (fun k' -> if k' = k then (frame <: b k') else v_new k') in
    composable (prod_pcm p) y' frame' /\
    op (prod_pcm p) frame' y' `feq` v_new
  ));
  assert (compatible (prod_pcm p) y' v_new);
  assert (forall (frame:_{composable (prod_pcm p) ((field_to_struct p k).morph x) frame}).
       composable (prod_pcm p) ((field_to_struct p k).morph y) frame /\
       (op (prod_pcm p) ((field_to_struct p k).morph x) frame == v ==> op (prod_pcm p) ((field_to_struct p k).morph y) frame `feq` v_new));
  ()

#pop-options

let struct_field_lift_fpu
  (#a: eqtype)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (k: a)
  (x: Ghost.erased (b k) { ~ (Ghost.reveal x == one (p k)) })
  (y: Ghost.erased (b k))
  (f: frame_preserving_upd (p k) x y)
: Tot (frame_preserving_upd (prod_pcm p) ((field_to_struct p k).morph x) ((field_to_struct p k).morph y))
= fun v ->
    struct_field_lift_fpu_prf p k x y f v;
    struct_field_lift_fpu' p k x y f v

let struct_field
  (#a: eqtype)
  (#b: a -> Type u#b)
  (p:(k: a -> pcm (b k)))
  (k: a)
: Tot (connection (prod_pcm p) (p k))
= mkconnection
    (field_to_struct p k)
    (struct_to_field p k)
    ()
    (struct_field_lift_fpu p k)

let exclusive_struct_intro
  (#a: Type)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (x: restricted_t a b)
: Lemma
  (requires (
    forall k . exclusive (p k) (struct_to_field_f p k x)
  ))
  (ensures (
    exclusive (prod_pcm p) x
  ))
  [SMTPat (exclusive (prod_pcm p) x)]
=
  assert (forall frame . prod_comp p x frame ==> frame `feq` prod_one p)

let exclusive_struct_elim
  (#a: eqtype)
  (#b: a -> Type)
  (p:(k: a -> pcm (b k)))
  (x: restricted_t a b)
  (k: a)
: Lemma
  (requires (exclusive (prod_pcm p) x))
  (ensures (exclusive (p k) (struct_to_field_f p k x)))
=
  let phi
    frame
  : Lemma
    (requires (composable (p k) (struct_to_field_f p k x) frame))
    (ensures (composable (prod_pcm p) x (field_to_struct_f p k frame)))
    [SMTPat (composable (p k) (struct_to_field_f p k x) frame)]
  = let x' = struct_to_field_f p k x in
    let f' = field_to_struct_f p k frame in
    let psi
      k'
    : Lemma
      (composable (p k') (x k') (f' k'))
      [SMTPat (composable (p k') (x k') (f' k'))]
    = if k' = k
      then ()
      else is_unit (p k') (x k')
    in
    ()
  in
  ()

let struct_without_field (#a:eqtype) (#b: a -> Type u#b) (p:(k:a -> pcm (b k))) (k:a)
  (xs: restricted_t a b)
: restricted_t a b
= on_dom a (fun k' -> if k' = k then one (p k) else xs k')

let struct_peel (#a:eqtype) (#b: a -> Type u#b) (p:(k:a -> pcm (b k))) (k:a)
  (xs: restricted_t a b)
: Lemma (
    composable (prod_pcm p) (struct_without_field p k xs) (field_to_struct_f p k (xs k)) /\
    xs == op (prod_pcm p) (struct_without_field p k xs) (field_to_struct_f p k (xs k)))
= Classical.forall_intro_2 (fun k -> is_unit (p k));
  assert (xs `feq` op (prod_pcm p) (struct_without_field p k xs) (field_to_struct_f p k (xs k)))

let addr_of_struct_field
  (#base:Type) (#a:eqtype) (#b: a -> Type u#b) (#p:(k:a -> pcm (b k)))
  (r: ref base (prod_pcm p)) (k:a)
  (xs: Ghost.erased (restricted_t a b))
: Steel (ref base (p k))
    (r `pts_to` xs)
    (fun s ->
      (r `pts_to` struct_without_field p k xs) `star` 
      (s `pts_to` Ghost.reveal xs k))
    (requires fun _ -> True)
    (ensures fun _ r' _ -> r' == ref_focus r (struct_field p k))
= struct_peel p k xs;
  split r xs (struct_without_field p k xs) (field_to_struct_f p k (Ghost.reveal xs k));
  let r = focus r (struct_field p k) (field_to_struct_f p k (Ghost.reveal xs k)) (Ghost.reveal xs k) in
  A.return r

(*
let ptr_addr_of_struct_field
  (#base:Type) (#a:eqtype) (#b: a -> Type u#b) (#p:(k:a -> pcm (b k)))
  (r: Ptr.ptr base (prod_pcm p)) (k:a)
  (xs: Ghost.erased (restricted_t a b))
: Steel (ref base (p k))
    (r `pts_to` xs)
    (fun s ->
      (r `pts_to` struct_without_field p k xs) `star` 
      (s `pts_to` Ghost.reveal xs k))
    (requires fun _ -> True)
    (ensures fun _ r' _ -> r' == ref_focus r (struct_field p k))
= struct_peel p k xs;
  split r xs (struct_without_field p k xs) (field_to_struct_f p k (Ghost.reveal xs k));
  let r = focus r (struct_field p k) (field_to_struct_f p k (Ghost.reveal xs k)) (Ghost.reveal xs k) in
  A.return r
*)

let struct_with_field (#a:eqtype) (#b: a -> Type u#b) (p:(k:a -> pcm (b k))) (k:a)
  (x:b k) (xs: restricted_t a b)
: restricted_t a b
= on_dom a (fun k' -> if k' = k then x else xs k')

let struct_unpeel (#a:eqtype) (#b: a -> Type u#b) (p:(k:a -> pcm (b k))) (k:a)
  (x: b k) (xs: restricted_t a b)
: Lemma
    (requires xs k == one (p k))
    (ensures
      composable (prod_pcm p) xs (field_to_struct_f p k x) /\
      struct_with_field p k x xs == op (prod_pcm p) xs (field_to_struct_f p k x))
= Classical.forall_intro_2 (fun k -> is_unit (p k));
  assert (struct_with_field p k x xs `feq` op (prod_pcm p) xs (field_to_struct_f p k x))

let unaddr_of_struct_field
  (#base:Type) (#a:eqtype) (#b: a -> Type u#b) (#p:(k:a -> pcm (b k))) (k:a)
  (r': ref base (p k)) (r: ref base (prod_pcm p))
  (xs: Ghost.erased (restricted_t a b)) (x: Ghost.erased (b k))
: Steel unit
    ((r `pts_to` xs) `star` (r' `pts_to` x))
    (fun s -> r `pts_to` struct_with_field p k x xs)
    (requires fun _ -> r' == ref_focus r (struct_field p k) /\ Ghost.reveal xs k == one (p k))
    (ensures fun _ _ _ -> True)
= unfocus r' r (struct_field p k) x;
  gather r xs (field_to_struct_f p k x);
  struct_unpeel p k x xs;
  A.change_equal_slprop (r `pts_to` _) (r `pts_to` _);
  A.return ()

let struct_view_to_view_prop
  (#a:Type) (#b: a -> Type) (#p:(k:a -> pcm (b k)))
  (fa:a -> prop)
  (view_t:(refine a fa -> Type))
  (field_view:(k:refine a fa -> sel_view (p k) (view_t k)))
: restricted_t a b -> Tot prop
= fun (f : restricted_t a b) ->
  forall (k:a).
    (fa k ==> (field_view k).to_view_prop (f k))

let struct_view_to_view
  (#a:Type) (#b: a -> Type) (#p:(k:a -> pcm (b k)))
  (#fa:a -> prop)
  (view_t:(refine a fa -> Type))
  (field_view:(k:refine a fa -> sel_view (p k) (view_t k)))
: refine (restricted_t a b) (struct_view_to_view_prop fa view_t field_view) ->
  Tot (restricted_t (refine a fa) view_t)
= fun (f: refine (restricted_t a b) (struct_view_to_view_prop fa view_t field_view)) ->
  let g = on_dom (refine a fa) (fun (k: refine a fa) -> (field_view k).to_view (f k)) in
  g

let decidable (p: 'a -> prop) = decide:('a -> bool){forall x. decide x <==> p x}

let struct_view_to_carrier
  (#a:Type) (#b: a -> Type) (#p:(k:a -> pcm (b k)))
  (#fa:a -> prop)
  (dec_fa: decidable fa)
  (view_t:(refine a fa -> Type))
  (field_view:(k:refine a fa -> sel_view (p k) (view_t k)))
: restricted_t (refine a fa) view_t ->
  Tot (refine (restricted_t a b) (struct_view_to_view_prop fa view_t field_view))
= fun (f: restricted_t (refine a fa) view_t) ->
  let g: restricted_t a b = on_dom a (fun k ->
    if dec_fa k then
      (field_view k).to_carrier (f k) <: b k
    else one (p k))
  in g

let struct_view_to_carrier_not_one
  (#a:Type) (#b: a -> Type) (#p:(k:a -> pcm (b k)))
  (#fa:a -> prop)
  (dec_fa: decidable fa)
  (view_t:(refine a fa -> Type))
  (field_view:(k:refine a fa -> sel_view (p k) (view_t k)))
  (x:restricted_t (refine a fa) view_t)
: Lemma
    (requires exists (k:a). fa k)
    (ensures struct_view_to_carrier dec_fa view_t field_view x =!= one (prod_pcm p))
= let k = FStar.IndefiniteDescription.indefinite_description_ghost a fa in
  (field_view k).to_carrier_not_one (x k)

let struct_view_to_view_frame
  (#a:Type) (#b: a -> Type) (#p:(k:a -> pcm (b k)))
  (#fa:a -> prop)
  (dec_fa: decidable fa)
  (view_t:(refine a fa -> Type))
  (field_view:(k:refine a fa -> sel_view (p k) (view_t k)))
  (x:restricted_t (refine a fa) view_t)
  (frame: restricted_t a b)
: Lemma
    (requires (composable (prod_pcm p) (struct_view_to_carrier dec_fa view_t field_view x) frame))
    (ensures
      struct_view_to_view_prop fa view_t field_view
        (op (prod_pcm p) (struct_view_to_carrier dec_fa view_t field_view x) frame) /\ 
      struct_view_to_view view_t field_view
        (op (prod_pcm p) (struct_view_to_carrier dec_fa view_t field_view x) frame) == x)
= let aux (k:refine a fa)
  : Lemma (
      (field_view k).to_view_prop (op (p k) ((field_view k).to_carrier (x k)) (frame k)) /\
      (field_view k).to_view (op (p k) ((field_view k).to_carrier (x k)) (frame k)) == x k)
  = assert (composable (p k) ((field_view k).to_carrier (x k)) (frame k));
    (field_view k).to_view_frame (x k) (frame k)
  in forall_intro aux;
  assert (
    struct_view_to_view view_t field_view
       (op (prod_pcm p) (struct_view_to_carrier dec_fa view_t field_view x) frame) `feq` x)

let struct_view
  (#a:Type) (#b: a -> Type) (#p:(k:a -> pcm (b k)))
  (#fa:a -> prop)
  (dec_fa:decidable fa)
  (view_t:refine a fa -> Type)
  (field_view:(k:refine a fa -> sel_view (p k) (view_t k)))
: Pure (sel_view (prod_pcm p) (restricted_t (refine a fa) view_t))
    (requires exists (k:a). fa k)
    (ensures fun _ -> True)
= {
  to_view_prop = struct_view_to_view_prop fa view_t field_view;
  to_view = struct_view_to_view view_t field_view;
  to_carrier = struct_view_to_carrier dec_fa view_t field_view;
  to_carrier_not_one = struct_view_to_carrier_not_one dec_fa view_t field_view;
  to_view_frame = struct_view_to_view_frame dec_fa view_t field_view;
}