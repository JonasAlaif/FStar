module AggregateRefExamples

open Aggregates
open AggregateRef
open FStar.PCM
open FStar.FunctionalExtensionality

open Steel.Effect
module A = Steel.Effect.Atomic

/// Example 1: swapping the coordinates of a 2d point
///
/// struct point { int x, y; };
///
/// void swap(struct point *p) {
///   int *q = &p.x;
///   int *r = &p.y;
///   int tmp = *q;
///   *q = *r;
///   *r = tmp;
/// }

/// Carrier of PCM for struct point:

type point_field = | X | Y
let point_fields k = match k with
  | X -> option int
  | Y -> option int
let point = restricted_t point_field point_fields

/// PCM for struct point:

let int_pcm = opt_pcm #int
let point_fields_pcm k : pcm (point_fields k) = match k with
  | X -> int_pcm
  | Y -> int_pcm
let point_pcm = prod_pcm point_fields_pcm

let mk_point_f (x y: option int) (k: point_field): point_fields k = match k with
  | X -> x
  | Y -> y
let mk_point (x y: option int): point = on_domain point_field (mk_point_f x y)

let put_x x' x y
: Lemma (put (field point_fields_pcm X) x' (mk_point x y) == mk_point x' y)
  [SMTPat (put (field point_fields_pcm X) x' (mk_point x y))]
= admit()

let get_x x y
: Lemma (get (field point_fields_pcm X) (mk_point x y) == x)
  [SMTPat (get (field point_fields_pcm X) (mk_point x y))]
= admit()

let put_y y' x y
: Lemma (put (field point_fields_pcm Y) y' (mk_point x y) == mk_point x y')
  [SMTPat (put (field point_fields_pcm Y) y' (mk_point x y))]
= admit()

let get_y x y
: Lemma (get (field point_fields_pcm Y) (mk_point x y) == y)
  [SMTPat (get (field point_fields_pcm Y) (mk_point x y))]
= admit()

let merge_xy x y x' y'
: Lemma (op (prod_pcm point_fields_pcm) (mk_point x y) (mk_point x' y') ==
         mk_point (op (point_fields_pcm X) x x') (op (point_fields_pcm Y) y y'))
  [SMTPat (op (prod_pcm point_fields_pcm) (mk_point x y) (mk_point x' y'))]
= admit()

let addr_of_x (p: ref 'a point{p.q == point_pcm}) (x y: Ghost.erased (option int))
: SteelT (q:ref 'a (option int){q == ref_focus p int_pcm (field point_fields_pcm X)})
    (to_vprop (p `pts_to` mk_point x y))
    (fun q ->
       to_vprop (p `pts_to` mk_point None y) `star`
       to_vprop (q `pts_to` x))
= let q = addr_of_lens p int_pcm (field point_fields_pcm X) (mk_point x y) in
  change_equal_vprop (p `pts_to` _) (p `pts_to` mk_point None y);
  change_equal_vprop (q `pts_to` _) (q `pts_to` x);
  A.return q

let addr_of_y (p: ref 'a point{p.q == point_pcm}) (x y: Ghost.erased (option int))
: SteelT (q:ref 'a (option int){q == ref_focus p int_pcm (field point_fields_pcm Y)})
    (to_vprop (p `pts_to` mk_point x y))
    (fun q ->
       to_vprop (p `pts_to` mk_point x None) `star`
       to_vprop (q `pts_to` y))
= let q = addr_of_lens p int_pcm (field point_fields_pcm Y) (mk_point x y) in
  change_equal_vprop (p `pts_to` _) (p `pts_to` mk_point x None);
  change_equal_vprop (q `pts_to` _) (q `pts_to` y);
  A.return q

#push-options "--z3rlimit 20 --print_implicits"
let swap (p: ref 'a point{p.q == point_pcm}) (x y: Ghost.erased int)
: SteelT unit
    (to_vprop (p `pts_to` mk_point (Some (Ghost.reveal x)) (Some (Ghost.reveal y))))
    (fun _ -> to_vprop (p `pts_to` mk_point (Some (Ghost.reveal y)) (Some (Ghost.reveal x))))
= (* int *q = &p.x; *)
  change_equal_vprop
    (p `pts_to` mk_point (Some (Ghost.reveal x)) (Some (Ghost.reveal y)))
    (p `pts_to` mk_point
      (Ghost.reveal (Ghost.hide (Some (Ghost.reveal x))))
      (Ghost.reveal (Ghost.hide (Some (Ghost.reveal y)))));
  let q = addr_of_x p (Some (Ghost.reveal x)) (Some (Ghost.reveal y)) in
  (* int *r = &p.y; *)
  change_equal_vprop
    (p `pts_to` mk_point None (Ghost.reveal (Ghost.hide (Some (Ghost.reveal y)))))
    (p `pts_to` mk_point (Ghost.reveal (Ghost.hide None))
      (Ghost.reveal (Ghost.hide (Some (Ghost.reveal y)))));
  let r = addr_of_y p None (Some (Ghost.reveal y)) in
  (* tmp = *q; *)
  let Some tmp = ref_read q (Some (Ghost.reveal x)) in
  assert (tmp = Ghost.reveal x);
  (* *q = *r; *)
  let Some vy = ref_read r (Some (Ghost.reveal y)) in
  assert (vy = Ghost.reveal y);
  ref_write q x vy;
  (* *r = tmp; *)
  ref_write r y tmp;
  (* Gather *)
  change_equal_vprop (q `pts_to` _) (q `pts_to` Some vy);
  unfocus q p (field point_fields_pcm X) (Some vy);
  unfocus r p (field point_fields_pcm Y) (Some tmp);
  gather p _ _;
  //gather p (mk_point (Ghost.reveal (Ghost.hide None)) None) _;
  //change_equal_vprop
  //  (p `pts_to` put (field point_fields_pcm X) (Ghost.reveal (Ghost.hide (Some vy))) (one p.q))
  //  (p `pts_to` mk_point (Some vy) None);
  //change_equal_vprop
  //  (p `pts_to` put (field point_fields_pcm Y) (Ghost.reveal (Ghost.hide (Some tmp))) (one p.q))
  //  (p `pts_to` mk_point None (Some tmp));
  A.sladmit ();
  A.return ()
#pop-options

(*
// let gather (r: ref 'a 'c) (x y: Ghost.erased 'c)
// : SteelT (_:unit{composable r.q x y})
//     (to_vprop (r `pts_to` x) `star` to_vprop (r `pts_to` y))
//     (fun _ -> to_vprop (r `pts_to` op r.q x y))

  (*
    (to_vprop (r `pts_to` x))
    (fun _ -> to_vprop (r' `pts_to` put l x (one r'.q)))
    (fun _ -> r == ref_focus r' q l)
    (fun _ _ _ -> True)
    *)

let unfocus #inames (r: ref 'a 'c) (r': ref 'a 'b) (q: refined_one_pcm 'c)
  (l: pcm_lens r'.q q) (x: Ghost.erased 'c)
: A.SteelGhost unit inames
    (to_vprop (r `pts_to` x))
    (fun _ -> to_vprop (r' `pts_to` put l x (one r'.q)))
    (fun _ -> r == ref_focus r' q l)
    (fun _ _ _ -> True)
= A.change_slprop_rel  
    (to_vprop (r `pts_to` x))
    (to_vprop (r' `pts_to` put l x (one r'.q)))
    (fun _ _ -> True)
    (fun m -> r'.pl.get_morphism.f_one ())
*)

(*
let swap (p: ref 'a point{p.q == point_pcm}) (xy: Ghost.erased int)
: SteelT unit
    (to_vprop (p `pts_to` xy))
    (fun _ -> to_vprop (p `pts_to` mk_point (xy Y) (xy X)))
  
let swap (p: ref 'a point{p.q == point_pcm}) (xy: Ghost.erased int)
: SteelT unit
    (to_vprop (p `pts_to` xy))
    (fun _ -> to_vprop (p `pts_to` xy `upd` (X, xy Y) `upd` (Y, xy X)))

let swap (p: ref 'a point{p.q == point_pcm}) (x y: Ghost.erased int)
: SteelT unit
    (to_vprop (p `pts_to` mk_point (Some (Ghost.reveal x)) (Some (Ghost.reveal y))))
    (fun _ -> to_vprop (p `pts_to` mk_point (Some (Ghost.reveal y)) (Some (Ghost.reveal x))))
= let q =
    addr_of_lens p int_pcm (field point_fields_pcm X)
      (mk_point (Some (Ghost.reveal x)) (Some (Ghost.reveal y))) in
  A.slassert (
    to_vprop (p `pts_to` mk_point None (Some (Ghost.reveal y))) `star`
    to_vprop (q `pts_to` Some (Ghost.reveal x)));
  A.sladmit ();
  A.return ()
*)

// let addr_of_lens (r: ref 'a 'b) (q: refined_one_pcm 'c) (l: pcm_lens r.q q) (x: Ghost.erased 'b)
// : SteelT (ref 'a 'c)
//     (to_vprop (r `pts_to` x))
//     (fun s ->
//       to_vprop (r `pts_to` put l (one q) x) `star` 
//       to_vprop (s `pts_to` get l x))
// = peel r q l x;
//   focus r q l (put l (get l x) (one r.q)) (get l x)

(*
let swap (p: ref 'a point) (x y: Ghost.erased (option int))
: Steel unit
    (to_vprop (r `pts_to` mk_point x y))
    (fun _ -> to_vprop (r `pts_to` mk_point y x))
= 
let ref_read (r: ref 'a 'b) (x: Ghost.erased 'b)
: Steel 'b
    (to_vprop (r `pts_to` x)) 
    (fun _ -> to_vprop (r `pts_to` x))
    (requires fun _ -> True)
    (ensures fun _ x' _ -> compatible r.q x x')*)

(** Example: a model for a tagged union representing colors in RGB or HSV
      type color =
        | RGB : r:int -> g:int -> b:int -> color
        | HSV : h:int -> s:int -> v:int -> color *)

type rgb_field = | R | G | B
type hsv_field = | H | S | V
type color_tag = | RGB | HSV

(* Carrier of all-or-none PCM for integers *)
let int_pcm_t = option int

(* Type families for fields of RGB and HSV structs *)
let rgb_fields k = match k with
  | R -> int_pcm_t
  | G -> int_pcm_t
  | B -> int_pcm_t
let hsv_fields k = match k with
  | H -> int_pcm_t
  | S -> int_pcm_t
  | V -> int_pcm_t
  
(** Carriers of PCMs for RGB and HSV structs *)
let rgb_t = restricted_t rgb_field rgb_fields
let hsv_t = restricted_t hsv_field hsv_fields

(** Type family for union of RGB and HSV *)
let color_cases t = match t with
  | RGB -> rgb_t
  | HSV -> hsv_t

(** Carrier of PCM for color *)
let color_t = union color_cases

(** All-or-none PCM for integers *)
let int_pcm : pcm int_pcm_t = opt_pcm

(** PCMs for RGB and HSV structs *)
let rgb_pcm : pcm (restricted_t rgb_field rgb_fields) =
  prod_pcm #_ #rgb_fields (fun k -> match k with
    | R -> int_pcm
    | G -> int_pcm
    | B -> int_pcm)
let hsv_pcm : pcm (restricted_t hsv_field hsv_fields) =
  prod_pcm #_ #hsv_fields (fun k -> match k with
    | H -> int_pcm
    | S -> int_pcm
    | V -> int_pcm)

(** PCM for color *)
let color_pcm_cases k : pcm (color_cases k) = match k with
  | RGB -> rgb_pcm
  | HSV -> hsv_pcm
let color_pcm : pcm color_t = union_pcm color_pcm_cases
