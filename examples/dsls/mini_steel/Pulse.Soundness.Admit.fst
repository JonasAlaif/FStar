module Pulse.Soundness.Admit

open FStar.Reflection
open Refl.Typing
open Pulse.Elaborate.Pure
open Pulse.Typing
open Pulse.Soundness.Common

module EPure = Pulse.Elaborate.Pure
module RT = Refl.Typing

let stt_admit_soundness
  (#f:stt_env)
  (#g:env)
  (#u:universe)
  (#a:term)
  (#p:term)
  (#q:term)
  (a_typing:RT.typing (extend_env_l f g) a (pack_ln (Tv_Type u)))
  (p_typing:RT.typing (extend_env_l f g) p vprop_tm)
  (q_typing:RT.typing (extend_env_l f g) q (mk_arrow (a, Q_Explicit) vprop_tm))

  : GTot (RT.typing (extend_env_l f g)
                    (mk_stt_admit u a p q)
                    (mk_stt_comp u a p q)) = admit ()
               
let stt_atomic_admit_soundness
  (#f:stt_env)
  (#g:env)
  (#u:universe)
  (#a:term)
  (#p:term)
  (#q:term)
  (a_typing:RT.typing (extend_env_l f g) a (pack_ln (Tv_Type u)))
  (p_typing:RT.typing (extend_env_l f g) p vprop_tm)
  (q_typing:RT.typing (extend_env_l f g) q (mk_arrow (a, Q_Explicit) vprop_tm))

  : GTot (RT.typing (extend_env_l f g)
                    (mk_stt_atomic_admit u a p q)
                    (mk_stt_atomic_comp u a emp_inames_tm p q)) = admit ()

let stt_ghost_admit_soundness
  (#f:stt_env)
  (#g:env)
  (#u:universe)
  (#a:term)
  (#p:term)
  (#q:term)
  (a_typing:RT.typing (extend_env_l f g) a (pack_ln (Tv_Type u)))
  (p_typing:RT.typing (extend_env_l f g) p vprop_tm)
  (q_typing:RT.typing (extend_env_l f g) q (mk_arrow (a, Q_Explicit) vprop_tm))

  : GTot (RT.typing (extend_env_l f g)
                    (mk_stt_ghost_admit u a p q)
                    (mk_stt_ghost_comp u a emp_inames_tm p q)) = admit ()