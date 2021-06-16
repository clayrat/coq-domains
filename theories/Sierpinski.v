Require Import Preamble Preorder Poset Dcpo.

Definition Σ := Prop.
Definition Σ_lt (x y : Σ) := x → y.

Lemma Σ_ltR : ∀ x : Σ, x → x.
Proof. auto. Qed.

Lemma Σ_ltT : ∀ x y z : Σ, (x → y) → (y → z) → x → z.
Proof. auto. Qed.

HB.instance Definition Σ_preorder_axioms := PreorderOfType.Build Σ Σ_lt Σ_ltR Σ_ltT.

Lemma Σ_ltE : ∀ x y : Σ, (x ≤ y) → (y ≤ x) → x = y.
Proof. move=> *; apply: propext; by split. Qed.

HB.instance Definition Σ_poset_axioms := PosetOfPreorder.Build Σ Σ_ltE.

Lemma Σ_exists_is_lub : ∀ (A : Family Σ), is_lub A (∃ x, A x).
  move=> A; split.
  - by compute; eauto.
  - move=> z zub; move=> [? ?].
    by apply: zub; eauto.
Qed.

Lemma Σ_ltHasDLubs : ∀ (A : Family Σ), is_directed A → ∃ x, is_lub A x.
Proof.
  move=> A dir //=.
  exists (∃ x, A x).
  apply: Σ_exists_is_lub.
Qed.

HB.instance Definition Σ_dcpo_axioms := DcpoOfPoset.Build Σ Σ_ltHasDLubs.

Lemma Σ_ltHasBot : ∃ x : Σ, is_bottom x.
Proof. exists False; by move=> ?. Qed.

Lemma Σ_ltHasTop : ∃ x : Σ, is_top x.
Proof. exists True; by move=> ?. Qed.

HB.instance Definition Σ_pointed_poset_axioms := PointedPosetOfPoset.Build Σ Σ_ltHasBot.
HB.instance Definition Σ_bounded_poset_axioms := BoundedPosetOfPointedPoset.Build Σ Σ_ltHasTop.

Lemma Σ_top_rw : (⊤ : Σ) = True.
  apply: top_is_unique.
  - apply: top_is_top.
  - done.
Qed.

Lemma Σ_bot_rw : (⊥ : Σ) = False.
  apply: bottom_is_unique.
  - apply: bottom_is_bottom.
  - by compute.
Qed.

Lemma Σ_lub_intro (A : Family Σ): ∀ u ϕ, is_lub A ϕ → A u → ϕ.
Proof. move=> u ϕ ϕlub; by apply: (lub_is_ub A ϕ ϕlub u). Qed.


Lemma Σ_lub_elim {P Q: Σ} {A} : is_lub A P → (∀ x, A x → Q) → P → Q.
Proof.
  move=> H J.
  rewrite -(lub_unique _ _ _ (Σ_exists_is_lub _) H).
  case; apply: J.
Qed.
