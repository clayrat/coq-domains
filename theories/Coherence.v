From mathcomp Require Export seq.
From Domains Require Import Preamble Preorder Poset Dcpo.
From Coq Require Import Relations.

(* ported from https://github.com/CertiKOS/rbgs/blob/master/models/Coherence.v *)

Unset Program Cases.
Local Obligation Tactic := auto.
Set Bullet Behavior "None".

(** * Coherence spaces *)

(** ** Definition *)

Record space :=
  {
    token : Type;
    coh: relation token;
    coh_refl: reflexive _ coh;
    coh_symm: symmetric _ coh;
  }.

Arguments coh {_}.
Bind Scope coh_scope with space.
Delimit Scope coh_scope with coh.

(** ** Cliques *)

(** A point in a coherence space is a set of pairwise coherent tokens. *)

Record clique (A : space) :=
  {
    has : token A -> Prop;
    has_coh a b : has a -> has b -> coh a b;
  }.

Arguments has {A}.
Bind Scope clique_scope with clique.
Delimit Scope clique_scope with clique.
Open Scope clique_scope.

(** ** Ordering *)

(* Points are ordered by inclusion and form a DCPPO. *)

Definition ref {A} : relation (clique A) :=
  fun x y => forall a, has x a -> has y a.

Lemma refR {A} : reflexive _ (@ref A).
Proof. by move=>c ta. Qed.

Lemma refT {A} : transitive _ (@ref A).
Proof.
move=>cx cy cz Hxy Hyz ta Ha.
by apply/Hyz/Hxy.
Qed.

HB.instance Definition ref_preo A := PreorderOfType.Build (clique A) ref refR refT.

Lemma refA {A} : antisymmetric _ (@ref A).
Proof.
move=>[ha ca][hb cb]; rewrite /ref /= => Hxy Hyx.
have E: ha = hb.
- by apply: funext=>t; apply: propext; split; [apply: Hxy | apply: Hyx].
rewrite E in ca cb *.
by rewrite (proofirr _ ca cb).
Qed.

HB.instance Definition ref_po A := PosetOfPreorder.Build (clique A) refA.

(** ** DCPPO structure *)

(** *** Least element *)

Program Definition bot A : clique A :=
  {|
    has a := False;
  |}.
Next Obligation. by []. Qed.

Lemma ref_bot {A} : ∃ x : clique A, is_bottom x.
Proof. by exists (bot A)=>x a. Qed.

HB.instance Definition ref_ppo A := PointedPosetOfPoset.Build (clique A) ref_bot.

(** *** Directed supremum *)

Program Definition lim {A} (F : Family (clique A)) (D : is_directed F) : clique A :=
  {|
    has a := exists i, has (fam_val F i) a;
  |}.
Next Obligation.
move=>A F [_ P] i j [x Hx][y Hy].
case: (P x y)=>z [Fx Fy].
move: (Fx i Hx)=>Hz1; move: (Fy j Hy)=>Hz2.
by apply: (has_coh _ (F z) _ _ Hz1 Hz2).
Qed.

Lemma ref_HasDLubs {A} (F : Family (clique A)) : is_directed F → ∃ x, is_lub F x.
Proof.
move=>/= D; exists (lim _ D); split=>/=.
- by move=>q ta Ha /=; exists q.
by move=>c Hc a /= [q Hq]; apply: (Hc q).
Qed.

HB.instance Definition ref_dcpo A := DcpoOfPoset.Build (clique A) ref_HasDLubs.

(** * Basic categorical structure *)

(** ** Linear maps *)

(** *** Definition *)

(** Linear maps are defined as cliques in the space [A --o B]. *)

Program Definition lmap (A B : space) : space :=
  {|
    token := token A * token B;
    coh '(a1, b1) '(a2, b2) :=
      coh a1 a2 -> coh b1 b2 /\ (b1 = b2 -> a1 = a2);
  |}.
Next Obligation.
move=>A B [a b] _; split=>//.
by apply: coh_refl.
Qed.
Next Obligation.
move=>A B [a1 b1][a2 b2] H /coh_symm /H; case=>Hb He.
split; first by apply: coh_symm.
by move=>E; symmetry; apply: He.
Qed.

Infix "--o" := lmap (at level 55, right associativity) : coh_scope.
Notation "A --o B" := (clique (A --o B)) : type_scope.

(** *** Properties *)

Lemma lmap_cohdet {A B} (f : A --o B) (a1 a2 : token A) (b1 b2 : token B) :
  coh a1 a2 -> has f (a1, b1) -> has f (a2, b2) ->
  coh b1 b2 /\ (b1 = b2 -> a1 = a2).
Proof. by move=>Ha H1 H2; case: (has_coh _ f _ _ H1 H2 Ha). Qed.

Lemma lmap_ext {A B} (f g : A --o B):
  (forall x y, has f (x, y) <-> has g (x, y)) -> f = g.
Proof. by move=>H; apply: ltE; case=>a b Ha; apply/H. Qed.

(** ** Identity and composition *)

Program Definition lmap_id {A : space} : A --o A :=
  {|
    has '(x, y) := x = y;
  |}.
Next Obligation. by move=>A [a1 b1] [a2 b2] /= ->->. Qed.

Program Definition lmap_compose {A B C} (g : B --o C) (f : A --o B) : A --o C :=
  {|
    has '(x, z) := exists y, has f (x, y) /\ has g (y, z);
  |}.
Next Obligation.
move=>A B C [tg cg] [tf cf] [a1 c1] [a2 c2] /= [x [Hx1 Hx2]][y [Hy1 Hy2]] H.
move: (cf _ _ Hx1 Hy1)=>/(_ H); case=>Hxy Exy.
move: (cg _ _ Hx2 Hy2)=>/(_ Hxy); case=>Hc Ec.
by split=>// /Ec/Exy.
Qed.

Infix "@" := lmap_compose (at level 30, right associativity) : clique_scope.

Lemma lmap_compose_id_left {A B} (f : A --o B) :
  f @ lmap_id = f.
Proof.
apply: lmap_ext=>x y /=; split.
- by case=>z [->].
by move=>H; exists x.
Qed.

Lemma lmap_compose_id_right {A B} (f : A --o B) :
   lmap_id @ f = f.
Proof.
apply: lmap_ext=>x y /=; split.
- by case=>z [+ <-].
by move=>H; exists y.
Qed.

Lemma lmap_compose_assoc {A B C D} (h : C --o D) (g : B --o C) (f : A --o B) :
  (h @ g) @ f = h @ (g @ f).
Proof.
apply: lmap_ext=>x y /=; split.
- by case=>z [Hz][w][Hzw Hwy]; exists w; split=>//; exists z.
by case=>z [[w][Hxw Hwx]] H; exists w; split=>//; exists z.
Qed.

(** ** Action on cliques *)

(** The [clique A] type defines a functor of type [Coh -> Set]. Its
  action on linear maps transports them to functions on cliques. *)

Program Definition lmap_apply {A B} (f : A --o B) (x : clique A) : clique B :=
  {|
    has b := exists a, has x a /\ has f (a, b);
  |}.
Next Obligation.
move=>A B [tf cf] [tx cx] a b [y][/= Hxy Hfy][z][Hxz Hfz].
move: (cx _ _ Hxy Hxz)=>Hc.
by move: (cf _ _ Hfy Hfz)=>/(_ Hc) [].
Qed.

Lemma lmap_apply_id {A} (x : clique A) :
  lmap_apply lmap_id x = x.
Proof.
apply: ltE.
- by move=>a [b][H <-].
by move=>a Ha /=; exists a.
Qed.

Lemma lmap_apply_compose {A B C} (f : A --o B) (g : B --o C) (x : clique A) :
  lmap_apply (g @ f) x = lmap_apply g (lmap_apply f x).
Proof.
apply: ltE.
- by move=>c /= [a][Ha][b][Hfb Hgb]; exists b; split=>//; exists a.
by move=>c /= [b][[a][Ha Hf] Hb]; exists a; split=>//; exists b.
Qed.

(** ** Linear isomorphisms *)
(*
Record liso (A B : space) :=
  {
    liso_of :> token A -> token B -> Prop;
    liso_coh a1 a2 b1 b2 :
      liso_of a1 b1 ->
      liso_of a2 b2 ->
      (coh a1 a2 <-> coh b1 b2) /\
      (a1 = a2 <-> b1 = b2)
  }.

Arguments liso_of {A B}.
Infix "=~=" := liso (at level 70, right associativity) : type_scope.

Program Definition li_fw {A B} (f : A ~= B) :=
  {|
    lmaps := liso_of f;
  |}.
Next Obligation.
  destruct f as [f Hf]; cbn in *.
  destruct (Hf a1 a2 b1 b2) as [? ?]; auto.
  firstorder.
Qed.

Program Definition li_bw {A B} (f : A ~= B) :=
  {|
    lmaps x y := liso_of f y x;
  |}.
Next Obligation.
  destruct f as [f Hf]; cbn in *.
  destruct (Hf b1 b2 a1 a2) as [? ?]; auto.
  firstorder.
Qed.

Lemma li_bw_fw {A B} (f : A ~= B) :
  li_fw f @ li_bw f = lmap_id.
Proof.
  apply lmap_ext; intros x y.
  destruct f as [f Hf]; cbn in *.
  split.
  - intros (b & Hxb & Hby). cbn in *.
    destruct (Hf b b x y); auto. firstorder.
  - intros [ ]. exists x.
 apply liso_coh.
*)


(** * Simple constructions *)

(** ** Output *)

(** The covariant functor from [Set]. In terms of cliques this is the
  flat domain generated by [X]. *)

Program Definition output (X : Type) : space :=
  {|
    token := X;
    coh := eq;
  |}.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.

Program Definition omap {X Y} (f : X -> Y) : output X --o output Y :=
  {|
    has '(x, y) := f x = y;
  |}.
Next Obligation.
by move=>X Y f [a1 b1] [a2 b2] /= <-<- ->.
Qed.

Lemma omap_id {X} :
  omap (fun x:X => x) = lmap_id.
Proof. by apply: lmap_ext=>x y. Qed.

Lemma omap_compose {X Y Z} (f : X -> Y) (g : Y -> Z) :
  omap (fun x:X => g (f x)) = omap g @ omap f.
Proof.
apply: lmap_ext=>/= x y; split.
- by move=><-; exists (f x).
by case=>z[->].
Qed.

(** In fact, [output] is the left adjoint to [clique]. Here we give a
  characterization in terms of universal morphisms. *)

Program Definition oret {A} (a : A) : clique (output A) :=
  {|
    has := eq a;
  |}.
Next Obligation. by move=>A a x b=>->. Qed.

Program Definition oext {A B} (f : A -> clique B) : output A --o B :=
  {|
    has '(a, b) := has (f a) b;
  |}.
Next Obligation.
move=>A B f [a1 b1] [a2 b2] /= Ha Hb E; split=>//.
by apply: (has_coh _ _ _ _ Ha); rewrite E.
Qed.

Lemma oext_oret {A B} (f : A -> clique B) (a : A) :
  lmap_apply (oext f) (oret a) = f a.
Proof.
apply: ltE.
- by move=>b /= [x][->].
by move=>b /= H; exists a.
Qed.

Lemma oext_uniq {A B} (f : A -> clique B) (g : output A --o B) :
  (forall a, lmap_apply g (oret a) = f a) ->
  g = oext f.
Proof.
move=>H; apply: lmap_ext=>x y /=.
rewrite -H /=; split.
- by move=>Hg; exists x.
by case=>a [->].
Qed.

(** Here we could prove some consequences, in particular the
  isomorphisms between [output (A + B)] and [output A + output B],
  and between [clique (A && B)] and [clique A * clique B]. *)

(** ** Input *)

(** A contravariant functor from [Set]. Here the domain we obtain is
  essentially the powerset of [X]. For what its worth I believe the
  adjoint is the "coclique" contravariant functor [clique @ lneg]. *)

Program Definition input (X : Type) : space :=
  {|
    token := X;
    coh x1 x2 := True;
  |}.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.

Program Definition imap {X Y} (f : X -> Y) : input Y --o input X :=
  {|
    has '(y, x) := f x = y;
  |}.
Next Obligation.
by move=>X Y f [a1 b1] [a2 b2] /= <- <- _; split=>// ->.
Qed.

Lemma imap_id {X} :
  imap (fun x:X => x) = lmap_id.
Proof. by apply: lmap_ext=>x y. Qed.

Lemma imap_compose {X Y Z} (f : X -> Y) (g : Y -> Z) :
  imap (fun x:X => g (f x)) = imap f @ imap g.
Proof.
apply: lmap_ext=>/= z x; split.
- by move=><-; exists (f x).
by case=>y [<- ->].
Qed.


(** * Cartesian structure *)

(** ** Binary product *)

(** *** Definition *)

Inductive csprod_coh {A B} (RA : relation A) (RB : relation B) : relation (A + B) :=
  | inl_coh x y : RA x y -> csprod_coh RA RB (inl x) (inl y)
  | inr_coh x y : RB x y -> csprod_coh RA RB (inr x) (inr y)
  | inl_inr_coh x y : csprod_coh RA RB (inl x) (inr y)
  | inr_inl_coh x y : csprod_coh RA RB (inr x) (inl y).

Program Definition csprod (A B : space) : space :=
  {|
    token := token A + token B;
    coh := csprod_coh coh coh;
  |}.
Next Obligation.
move=>A B; case.
- move=>a; apply: inl_coh.
  by apply: coh_refl.
move=>b; apply: inr_coh.
by apply: coh_refl.
Qed.
Next Obligation.
move=>A B x y H; case: {-1}_ {-1}_ / H (erefl x) (erefl y) => a b.
- by move=>H _ _; apply/inl_coh/coh_symm.
- by move=>H _ _; apply/inr_coh/coh_symm.
- by move=>_ _; apply: inr_inl_coh.
by move=>_ _; apply: inl_inr_coh.
Qed.

Infix "&&" := csprod : coh_scope.

Program Definition csp1 {A B : space} : A && B --o A :=
  {|
    has '(x, a) := inl a = x;
  |}.
Next Obligation.
move=>A B [a1 b1][a2 b2] /= <-<- H.
case: {-1}_ {-1}_ / H (erefl (@inl _ (token B) b1)) (erefl (@inl _ (token B) b2))=>//.
by move=>x y H; case=>->; case=>->; split=>//->.
Qed.

Program Definition csp2 {A B : space} : A && B --o B :=
  {|
    has '(x, b) := inr b = x;
  |}.
Next Obligation.
move=>A B [a1 b1][a2 b2] /= <-<- H.
case: {-1}_ {-1}_ / H (erefl (@inr (token A) _ b1)) (erefl (@inr (token A) _ b2))=>//.
by move=>x y H; case=>->; case=>->; split=>//->.
Qed.

Program Definition cspair {X A B: space} (f: X --o A) (g: X --o B): X --o A && B :=
  {|
    has '(x, y) :=
      match y with
        | inl a => has f (x, a)
        | inr b => has g (x, b)
      end;
  |}.
Next Obligation.
move=>X A B f g /= [a1 b1][a2 b2]; case: b2=>b2; case: b1=>b1 H1 H2 Hc.
- case: (lmap_cohdet _ _ _ _ _ Hc H1 H2)=>Hcb E.
  by split; [apply: inl_coh | case].
- by split=>//; apply: inr_inl_coh.
- by split=>//; apply: inl_inr_coh.
case: (lmap_cohdet _ _ _ _ _ Hc H1 H2)=>Hcb E.
by split; [apply: inr_coh | case].
Qed.

Notation "{ x , y }" := (cspair x y) (x at level 99) : clique_scope.

(** *** Universal property *)

Lemma cspair_csp1 {X A B} (f : X --o A) (g : X --o B) :
  csp1 @ {f, g} = f.
Proof.
apply: lmap_ext=>x a /=; split.
- by case; case=>z; case=>// + [->].
by move=>Hxa; exists (inl a).
Qed.

Lemma cspair_csp2 {X A B} (f : X --o A) (g : X --o B) :
  csp2 @ {f, g} = g.
Proof.
apply: lmap_ext=>x b /=; split.
- by case; case=>z; case=>// + [->].
by move=>Hxb; exists (inr b).
Qed.

Lemma cspair_uniq {X A B} (h : X --o A && B) :
  {csp1 @ h, csp2 @ h} = h.
Proof.
apply: lmap_ext=>x; case=>/=.
- move=>a; split.
  - by case; case=>z; case=>// + [->].
  by move=>Hxa; exists (inl a).
move=>b; split.
- by case; case=>z; case=>// + [->].
by move=>Hxb; exists (inr b).
Qed.

(** ** Binary coproducts *)

(** *** Definition *)

Inductive cssum_coh {A B} (RA: relation A) (RB: relation B): relation (A + B) :=
  | sum_inl_coh x y : RA x y -> cssum_coh RA RB (inl x) (inl y)
  | sum_inr_coh x y : RB x y -> cssum_coh RA RB (inr x) (inr y).

Program Definition cssum (A B : space) : space :=
  {|
    token := token A + token B;
    coh := cssum_coh coh coh;
  |}.
Next Obligation.
move=>A B; case=>x.
- by apply/sum_inl_coh/coh_refl.
by apply/sum_inr_coh/coh_refl.
Qed.
Next Obligation.
move=>A B x y H; case: {-1}_ {-1}_ / H (erefl x) (erefl y) => a b.
- by move=>H _ _; apply/sum_inl_coh/coh_symm.
by move=>H _ _; apply/sum_inr_coh/coh_symm.
Qed.

Infix "+" := cssum : coh_scope.

Program Definition csi1 {A B : space} : A --o A + B :=
  {|
    has '(a, x) := inl a = x;
  |}.
Next Obligation.
move=>A B [a1 _][a2 _]<-<- Ha; split=>/=; last by case.
by apply: sum_inl_coh.
Qed.

Program Definition csi2 {A B : space} : B --o A + B :=
  {|
    has '(b, x) := inr b = x;
  |}.
Next Obligation.
move=>A B [a1 _][a2 _]<-<- Ha; split=>/=; last by case.
by apply: sum_inr_coh.
Qed.

Program Definition copair {A B X: space} (f: A --o X) (g: B --o X) : A+B --o X :=
  {|
    has '(x, y) :=
      match x with
        | inl a => has f (a, y)
        | inr b => has g (b, y)
      end;
  |}.
Next Obligation.
move=>A B X f g [ab1 x1][ab2 x2] /= H1 H2 H.
case: {-1}_ {-1}_ / H (erefl ab1) (erefl ab2) => a b H E1 E2;
rewrite {ab1}E1 in H1; rewrite {ab2}E2 in H2;
by case: (lmap_cohdet _ _ _ _ _ H H1 H2)=>Hx E; split=>// /E ->.
Qed.

Notation "[ x , y ]" := (copair x y) (x at level 99) : clique_scope.

(** *** Universal property *)

Lemma copair_csi1 {A B X} (f : A --o X) (g : B --o X) :
  [f, g] @ csi1 = f.
Proof.
apply: lmap_ext=>a x /=; split.
- by case; case=>z; case=>//; case=>->.
by move=>Hax; exists (inl a).
Qed.

Lemma copair_csi2 {A B X} (f : A --o X) (g : B --o X) :
  [f, g] @ csi2 = g.
Proof.
apply: lmap_ext=>b x /=; split.
- by case; case=>z; case=>//; case=>->.
by move=>Hax; exists (inr b).
Qed.

Lemma copair_uniq {A B X} (h : A + B --o X) :
  [h @ csi1, h @ csi2] = h.
Proof.
apply: lmap_ext; case=>[a|b] x /=; split.
- by case; case=>z; case=>//; case=>->.
- by move=>Hax; exists (inl a).
- by case; case=>z; case=>//; case=>->.
by move=>Hax; exists (inr b).
Qed.

(** ** Terminal object *)

(** *** Definition *)

Program Definition csterm : space :=
  {|
    token := Empty_set;
    coh x y := True;
  |}.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.

(** *** Universal property *)

Program Definition discard A : A --o csterm :=
  {|
    has '(x, y) := False;
  |}.
Next Obligation. by move=>A [a1 b1][a2 b2]. Qed.

Lemma discard_uniq {A} (f : A --o csterm) :
  f = discard A.
Proof. by apply: lmap_ext=>x. Qed.


(** * Tensor product *)

(** ** Definition *)

Program Definition cstens (A B : space) : space :=
  {|
    token := token A * token B;
    coh '(a1, b1) '(a2, b2) := coh a1 a2 /\ coh b1 b2;
  |}.
Next Obligation.
by move=>A B [a b]; split; apply: coh_refl.
Qed.
Next Obligation.
by move=>A B [a1 b1] [a2 b2] [Ha Hb]; split; apply: coh_symm.
Qed.

Infix "*" := cstens : coh_scope.

(** ** Functoriality *)

Program Definition cstens_lmap {A B C D} (f : A --o B) (g : C --o D) : A*C --o B*D :=
  {|
    has '((a, c), (b, d)) := has f (a, b) /\ has g (c, d);
  |}.
Next Obligation.
move=>A B C D f g [[a1 c1][b1 d1]][[a2 c2][b2 d2]][Hab1 Hcd1][Hab2 Hcd2][Ha Hc] /=.
case: (lmap_cohdet _ _ _ _ _ Ha Hab1 Hab2)=>Hb1 E1.
case: (lmap_cohdet _ _ _ _ _ Hc Hcd1 Hcd2)=>Hd1 E2.
by do !split=>//; case=>/E1 -> /E2 ->.
Qed.

Infix "*" := cstens_lmap : clique_scope.

Lemma cstens_id {A B} :
  (@lmap_id A) * (@lmap_id B) = lmap_id.
Proof.
by apply: lmap_ext=>[[a1 b1] [a2 b2]] /=; split; case=>->->.
Qed.

Lemma cstens_compose {A1 B1 C1} {A2 B2 C2}
    (f1 : A1 --o B1) (g1 : B1 --o C1) (f2 : A2 --o B2) (g2 : B2 --o C2) :
    (g1 @ f1) * (g2 @ f2) = (g1 * g2) @ (f1 * f2).
Proof.
apply: lmap_ext=>[[a1 a2][c1 c2]] /=; split.
- by case=>[[b1][Hf1 Hg1]][b2][Hf2 Hg2]; exists (b1, b2).
by case=>[[b1 b2][[Hf1 Hf2][Hg1 Hg2]]]; split; [exists b1 | exists b2].
Qed.

(** ** Unit *)

Program Definition csunit : space :=
  {|
    token := unit;
    coh x y := True;
  |}.
Next Obligation. by []. Qed.
Next Obligation. by []. Qed.

Notation "1" := csunit : coh_scope.

(*
(** Left unitor *)

Program Definition lam A : 1 * A --o A :=
  {|
Next Obligation.
  destruct H; auto.
Qed.

(** Right unitor *)

Program Definition rho A : A * 1 --o A :=
  {|
    lmap_apply a := (a, tt);
  |}.
Next Obligation.
  destruct H; auto.
Qed.
*)

(* etc.. *)

(** ** Negation *)

(** To avoid confusion between the [coh] relation associated with [A]
  and [lneg A], we introduce this singleton type. *)

Variant lneg_token A :=
  | ln (a : token A).

Arguments ln {A}.

(* TODO define anticlique? *)

Variant lneg_coh (A : space) : relation (lneg_token A) :=
  lneg_coh_intro x y :
    (coh x y -> x = y) -> lneg_coh A (ln x) (ln y).

Program Definition lneg (A : space) : space :=
  {|
    token := lneg_token A;
    coh := lneg_coh A;
  |}.
Next Obligation.
by move=>A [a]; apply: lneg_coh_intro.
Qed.
Next Obligation.
by move=>A _ _ [x y H]; apply: lneg_coh_intro=>/coh_symm/H.
Qed.

Program Definition lmap_flip {A B} (f : A --o B) : lneg B --o lneg A :=
  {|
    has '((ln x), (ln y)) := has f (y, x);
  |}.
Next Obligation.
move=>A B f [[b1 [a1]] [[b2][a2]]] H1 H2 /= H.
case: {-1}_ {-1}_ / H (erefl (ln b1) ) (erefl (ln b2)) => a b E [E1][E2].
rewrite {b1}E1 in H1; rewrite {b2}E2 in H2; split.
- apply: lneg_coh_intro=>H.
  by case: (lmap_cohdet _ _ _ _ _ H H1 H2)=>Hb1; apply; apply: E.
case=>Ea; rewrite {a1}Ea in H1.
have H := coh_refl _ a2.
by case: (lmap_cohdet _ _ _ _ _ H H1 H2)=>/E->.
Qed.


(** * Sequential constructions *)

(** ** Composition *)

Program Definition sequ (A B : space) : space :=
  {|
    token := token A * token B;
    coh '(a1, b1) '(a2, b2) := coh a1 a2 /\ (a1 = a2 -> coh b1 b2);
  |}.
Next Obligation.
by move=>A B [a b]; split=>[|_]; apply: coh_refl.
Qed.
Next Obligation.
move=>A B [a1 b1][a2 b2][Ha Hb]; split; first by apply: coh_symm.
by move=>E; rewrite E in Hb; apply/coh_symm/Hb.
Qed.

Infix ";;" := sequ (at level 40, left associativity) : coh_scope.

Program Definition sequ_lmap {A B C D} (f : A --o B) (g : C --o D) :
    (A ;; C) --o (B ;; D) :=
  {|
    has '((a, c), (b, d)) := has f (a, b) /\ has g (c, d);
  |}.
Next Obligation.
move=>A B C D f g [[a1 c1][b1 d1]][[a2 c2][b2 d2]] /=
  [Hab1 Hcd1] [Hab2 Hcd2] [Ha Ea].
case: (lmap_cohdet _ _ _ _ _ Ha Hab1 Hab2)=>Hb Eb; split.
- split=>// /Eb/Ea Hc.
  by case: (lmap_cohdet _ _ _ _ _ Hc Hcd1 Hcd2).
case=>/Eb /[dup] /Ea Hc ->.
by case: (lmap_cohdet _ _ _ _ _ Hc Hcd1 Hcd2)=>Hd /[apply] ->.
Qed.

Infix ";;" := sequ_lmap : lmap_scope.

(** ** Exponential *)

(* finite clique *)

Inductive seq_coh (A : space) : relation (seq (token A)) :=
  | nil_coh_l s :
      seq_coh A [::] s
  | nil_coh_r s :
      seq_coh A s [::]
  | cons_coh a b x y :
      coh a b ->
      (a = b -> seq_coh A x y) ->
      seq_coh A (a :: x) (b :: y).

Program Definition dag (A : space) : space :=
  {|
    token := seq (token A);
    coh := seq_coh A;
  |}.
Next Obligation.
move=>A; elim=>[|x s IH]; first by apply: nil_coh_l.
by apply: cons_coh=>//; apply: coh_refl.
Qed.
Next Obligation.
move=>A s t; elim=>{s t}[s|t|x y s t H H1 H2].
- by apply: nil_coh_r.
- by apply: nil_coh_l.
apply: cons_coh; first by apply: coh_symm.
by move=>E; apply: H2.
Qed.

Notation "! A" := (dag A)
  (at level 8, right associativity, format "'!' A") : coh_scope.

(** *** Comonad structure *)

Lemma prefix_coh {A} s1 s2 t1 t2 :
  seq_coh A (s1 ++ t1) (s2 ++ t2) ->
  seq_coh A s1 s2.
Proof.
move E1: (s1 ++ t1)=>st1; move E2: (s2 ++ t2)=>st2.
move=>H; elim: H s1 s2 E1 E2.
- move=>p s1 s2 /nilP; rewrite cat_nilp; case/andP=>/nilP-> _ _.
  by apply: nil_coh_l.
- move=>p s1 s2 _ /nilP; rewrite cat_nilp; case/andP=>/nilP-> _.
  by apply: nil_coh_r.
move=>x y p q H E IH s1 s2.
case: s1=>[|sx s1].
- by move=>_ _; apply: nil_coh_l.
case=>{sx}-> E1; case: s2=>[|sy s2].
- by move=>_; apply: nil_coh_r.
case=>{sy}-> E2; apply: cons_coh=>// Exy.
by apply: (IH Exy _ _ E1 E2).
Qed.

Lemma suffix_coh {A} s t1 t2 :
  seq_coh A (s ++ t1) (s ++ t2) ->
  seq_coh A t1 t2.
Proof.
  induction s; auto. cbn.
  inversion 1; clear H; subst.
  auto.
Qed.

Lemma app_coh {A} s t1 t2 :
  seq_coh A t1 t2 ->
  seq_coh A (s ++ t1) (s ++ t2).
Proof.
  intros Ht.
  induction s; auto.
  cbn. constructor.
  - reflexivity.
  - auto.
Qed.

(** Action on linear maps *)

Inductive dag_lmaps {A B} (f : A --o B) : token !A -> token !B -> Prop :=
  | dag_lmaps_nil :
      dag_lmaps f nil nil
  | dag_lmaps_cons a b aa bb :
      has f (a, b) ->
      dag_lmaps f aa bb ->
      dag_lmaps f (a :: aa) (b :: bb).

Program Definition dag_lmap {A B} (f : A --o B) : !A --o !B :=
  {|
    has '(aa, bb) := dag_lmaps f aa bb;
  |}.
Next Obligation.
  intros A B f [aa1 bb1] [aa2 bb2] Hab1 Hab2 Hxx.
  revert bb1 bb2 Hab1 Hab2.
  induction Hxx; intros.
  - inversion Hab1; clear Hab1; subst.
    split; [constructor | ].
    inversion 1; inversion Hab2; congruence.
  - inversion Hab2; clear Hab2; subst.
    split; [constructor | ].
    inversion 1; inversion Hab1; congruence.
  - inversion Hab1; clear Hab1; subst.
    inversion Hab2; clear Hab2; subst.
    split.
    + constructor; eauto using lmap_coh.
      intros. apply H1; eauto. eapply lmap_det; eauto.
    + inversion 1; subst.
      f_equal; eauto using lmap_det.
      edestruct H1; eauto using lmap_det.
Qed.

Notation "! f" := (dag_lmap f)
  (at level 8, right associativity, format "'!' f") : clique_scope.

Lemma dag_id {A} :
  !(@lmap_id A) = @lmap_id !A.
Proof.
  apply lmap_ext. split.
  - induction 1. constructor.
    cbn in *. congruence.
  - intros [ ].
    induction x; constructor; cbn; auto.
Qed.

Lemma dag_compose {A B C} (f : A --o B) (g : B --o C) :
  !(g @ f) = !g @ !f.
Proof.
  apply lmap_ext. split.
  - induction 1.
    + exists nil; split; constructor.
    + destruct H as (? & ? & ?), IHdag_lmaps as (? & ? & ?).
      exists (x :: x0). split; constructor; auto.
  - intros (u & Hxu & Huy). revert y Huy.
    induction Hxu.
    + inversion 1. constructor.
    + inversion 1; subst.
      constructor; auto.
      * eexists; eauto.
      * eapply IHHxu; eauto.
Qed.

(** Counit *)

Inductive dag_counit_lmaps A : token !A -> token A -> Prop :=
  dag_counit_intro a : dag_counit_lmaps A (a :: nil) a.

Program Definition dag_counit A : !A --o A :=
  {|
    has '(aa, a) := dag_counit_lmaps A aa a;
  |}.
Next Obligation.
  intros A [x1 a1] [x2 a2] Hx1 Hx2 Hx.
  destruct Hx1, Hx2. inversion Hx; clear Hx; subst.
  split; auto; congruence.
Qed.

Lemma dag_counit_natural {A B} (f : A --o B) :
   f @ dag_counit A = dag_counit B @ !f.
Proof.
  apply lmap_ext. split.
  - intros (a & Ha1 & Ha2).
    inversion Ha1. subst.
    eexists; repeat constructor; eauto.
  - intros (a & Ha1 & Ha2).
    inversion Ha2. subst.
    inversion Ha1 as [ | ? ? ? ? ? H]. subst.
    inversion H. subst.
    eexists; split; eauto; constructor.
Qed.

(** Comultiplication *)

Inductive dag_comult_lmaps {A} : token !A -> token !!A -> Prop :=
  | dag_comult_nil :
      dag_comult_lmaps nil nil
  | dag_comult_cons s a aa :
      dag_comult_lmaps a aa ->
      dag_comult_lmaps (s ++ a) (s :: aa).

Program Definition dag_comult A : !A --o !!A :=
  {|
    has '(a, aa) := dag_comult_lmaps a aa;
  |}.
Next Obligation.
  intros A [a1 aa1] [a2 aa2] H1 H2 Ha.
  revert a2 aa2 Ha H2.
  induction H1 as [ | s1 a1 aa1 H1].
  - split; [constructor | ].
    intros; subst. inversion H2. auto.
  - intros a2 aa2 Ha H2.
    induction H2 as [ | s2 a2 aa2 H2].
    + split.
      * constructor.
      * congruence.
    + split.
      * constructor.
        -- eapply prefix_coh; eauto.
        -- destruct 1.
           eapply IHH1; eauto.
           eapply suffix_coh; eauto.
      * inversion 1; subst. f_equal.
        eapply IHH1; eauto.
        eapply suffix_coh; eauto.
Qed.

Lemma dag_lmaps_app {A B} (f : A --o B) a1 a2 b1 b2:
  has !f (a1, b1) ->
  has !f (a2, b2) ->
  has !f (a1 ++ a2, b1 ++ b2).
Proof.
  induction 1.
  - intuition.
  - intros Hx.
    apply IHdag_lmaps in Hx.
    repeat rewrite <- app_comm_cons.
    constructor; assumption.
Qed.

Lemma dag_lmaps_app_inv {A B} (f : A --o B) a b1 b2:
  has !f (a, b1 ++ b2) ->
  exists a1 a2,
    a = a1 ++ a2 /\
    has !f (a1, b1) /\
    has !f (a2, b2).
Proof.
  revert a b2. induction b1 as [ | b1x b1xs].
  - intros a ? ?.
    exists nil. exists a.
    split. reflexivity.
    split. constructor.
    exact H.
  - intros a ? Ha.
    rewrite <- app_comm_cons in Ha.
    inversion Ha as [ | xa ? ? ? ? Hxa]. subst.
    apply IHb1xs in Hxa as [xa1 [xa2 [app_eq [Hxa1 Hxa2]]]].
    exists (xa::xa1). exists xa2.
    split. subst. apply app_comm_cons.
    split; try constructor; assumption.
Qed.

Lemma dag_comult_natural {A B} (f : A --o B) :
  !!f @ dag_comult A = dag_comult B @ !f.
Proof.
  apply lmap_ext. split.
  - intros (a & Ha1 & Ha2).
    revert y Ha2. induction Ha1 as [ | s a aa Ha IHaa].
    + inversion 1. eexists; split; constructor.
    + inversion 1 as [ | ? b ? ys Hy Hys]. subst.
      eapply IHaa in Hys as (bs & Hb1 & Hb2).
      inversion Ha2. subst.
      exists (b ++ bs). split. apply dag_lmaps_app; assumption.
      constructor. assumption.
  - intros (b & Hb1 & Hb2).
    revert x Hb1. induction Hb2 as [ | s b bb Hb IHbb].
    + inversion 1. eexists; split; constructor.
    + intros x Hx.
      apply dag_lmaps_app_inv in Hx as [a1 [a2 [? [Ha1 Ha2]]]].
      subst x. apply IHbb in Ha2 as (xa & ? & ?).
      exists (a1 :: xa); split. constructor. assumption.
      constructor; assumption.
Qed.

(** Properties *)

Lemma dag_comult_counit {A} :
  !(dag_counit A) @ (dag_comult A) = @lmap_id !A.
Proof.
  apply lmap_ext. split.
  - cbn. intros (a & Ha1 & Ha2).
    revert y Ha2. induction Ha1.
    + inversion 1. reflexivity.
    + inversion 1 as [ | ? ? ? ? Hsb Hab]. subst.
      apply IHHa1 in Hab.
      inversion Hsb. subst. reflexivity.
  - cbn. intros <-.
    exists (map (fun x => x::nil) x); split.
    + induction x.
      * constructor.
      * replace (a :: x) with ((a :: nil) ++ x) by reflexivity.
        constructor. assumption.
    + induction x; cbn; constructor.
      constructor. assumption.
Qed.

Lemma dag_counit_comult {A} :
  (dag_counit !A) @ (dag_comult A) = @lmap_id !A.
Proof.
  apply lmap_ext. split.
  - cbn. intros (a & Ha1 & Ha2).
    inversion Ha2. subst.
    inversion Ha1 as [ | ? ? ? H]. subst.
    inversion H. apply app_nil_r.
  - cbn. intros <-.
    exists (x::nil); split.
    + replace x with (x ++ nil) at 1 by apply app_nil_r; repeat constructor.
    + constructor.
Qed.

Lemma dag_comult_app {A} x y xs ys:
  has (dag_comult A) (x, xs) ->
  has (dag_comult A) (y, ys) ->
  has (dag_comult A) (x ++ y, xs ++ ys).
Proof.
  revert y ys.
  induction 1 as [ | s a aa H IH].
  - trivial.
  - intros Hy.
    apply IH in Hy.
    replace ((s++a)++y) with (s++(a++y)) by apply app_assoc.
    rewrite <- app_comm_cons.
    constructor. assumption.
Qed.

Lemma dag_comult_app_inv {A} a xs ys:
  has (dag_comult A) (a, xs ++ ys) ->
  exists x y,
    a = x ++ y /\
    has (dag_comult A) (x, xs) /\
    has (dag_comult A) (y, ys).
Proof.
  revert a ys.
  induction xs as [| x ? IHxs].
  - intros a ys Hys.
    exists nil. exists a.
    split. reflexivity.
    split. constructor.
    apply Hys.
  - intros a ys Hys.
    rewrite <- app_comm_cons in Hys.
    inversion Hys as [ | a1 a2 aa Haa]. subst.
    apply IHxs in Haa as [xxs [yys [app_eq [x_comult y_comult]]]].
    exists (x ++ xxs).
    exists yys.
    split. subst. apply app_assoc.
    split; try constructor; assumption.
Qed.

Lemma dag_comult_comult {A} :
  !(dag_comult A) @ (dag_comult A) = (dag_comult !A) @ (dag_comult A).
Proof.
  apply lmap_ext. split.
  - cbn. intros (aa & Haa1 & Haa2).
    revert y Haa2.
    induction Haa1 as [ | s a aa ? IH].
    + inversion 1. eexists; split; constructor.
    + intros y Hsaa.
      inversion Hsaa as [ | ? b ? bb Hb Hbb]. subst.
      apply IH in Hbb as (xaa & Hxaa1 & Hxaa2).
      exists (b++xaa); split.
      * apply dag_comult_app; assumption.
      * constructor. assumption.
  - cbn. intros (aa & Haa1 & Haa2).
    revert x Haa1.
    induction Haa2 as [ | s a aa ? IH].
    + inversion 1. eexists; split; constructor.
    + intros xa Hxa.
      apply dag_comult_app_inv in Hxa
        as (xa1 & xa2 & app_eq & xa1_comult & xa2_comult).
      apply IH in xa2_comult as (b & Hb1 & Hb2).
      exists (xa1::b); split; subst; constructor; assumption.
Qed.

(** Kleisli extension *)

Definition dag_ext {A B} (f : !A --o B) : !A --o !B :=
  dag_lmap f @ dag_comult A.

Lemma dag_ext_counit A :
  dag_ext (dag_counit A) = @lmap_id !A.
Proof.
  unfold dag_ext.
  apply dag_comult_counit.
Qed.

Lemma dag_counit_ext {A B} (f : !A --o B) :
  dag_counit B @ dag_ext f = f.
Proof.
  unfold dag_ext.
  rewrite <- lmap_compose_assoc.
  rewrite <- dag_counit_natural.
  rewrite lmap_compose_assoc.
  rewrite dag_counit_comult.
  rewrite lmap_compose_id_left.
  reflexivity.
Qed.

Lemma dag_ext_compose {A B C} (f : !A --o B) (g : !B --o C) :
  dag_ext (g @ dag_ext f) = dag_ext g @ dag_ext f.
Proof.
  unfold dag_ext.
  rewrite !lmap_compose_assoc.
  rewrite <- (lmap_compose_assoc (dag_comult B)).
  rewrite <- dag_comult_natural.
  rewrite !dag_compose, !lmap_compose_assoc.
  rewrite dag_comult_comult.
  reflexivity.
Qed.
