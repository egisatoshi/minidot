(* Clean-slate look at subtyping relation based on *)
(* singleton types (single env) *)

Require Export SfLib.

Require Export Arith.EqNat.
Require Export Arith.Lt.

Module STLC.

Definition id := nat.

Inductive ty : Type :=
  | TBot   : ty
  | TTop   : ty
  | TBool  : ty           
  | TFun   : ty -> ty -> ty
  | TVar   : bool -> id -> ty
  | TVarB  : id -> ty                   
  | TMem   : ty -> ty -> ty (* intro *)
  | TSel   : ty -> ty (* elim *)
  | TBind  : ty -> ty                   
.

Inductive vl : Type :=
  | vbool : bool -> vl
  | vabs  : ty -> ty -> vl
  | vty   : ty -> vl
.

Definition venv := list vl.
Definition tenv := list ty.

Hint Unfold venv.
Hint Unfold tenv.

Fixpoint index {X : Type} (n : id) (l : list X) : option X :=
  match l with
    | [] => None
    | a :: l'  => if beq_nat n (length l') then Some a else index n l'
  end.


(* closed j k means normal variables < i and < j, bound variables < k *)
Inductive closed: nat -> nat -> nat -> ty -> Prop :=
| cl_bot: forall i j k,
    closed i j k TBot
| cl_top: forall i j k,
    closed i j k TTop
| cl_bool: forall i j k,
    closed i j k TBool
| cl_fun: forall i j k T1 T2,
    closed i j k T1 ->
    closed i j k T2 ->
    closed i j k (TFun T1 T2)
| cl_var0: forall i j k x,
    i > x ->
    closed i j k (TVar false x)
| cl_var1: forall i j k x,
    j > x ->
    closed i j k (TVar true x)
| cl_varB: forall i j k x,
    k > x ->
    closed i j k (TVarB x)
| cl_mem: forall i j k T1 T2,
    closed i j k T1 ->
    closed i j k T2 ->        
    closed i j k (TMem T1 T2)
| cl_sel: forall i j k T1,
    closed i j k T1 ->
    closed i j k (TSel T1)
| cl_bind: forall i j k T1,
    closed i j (S k) T1 ->
    closed i j k (TBind T1)
.


Fixpoint open (k: nat) (u: ty) (T: ty) { struct T }: ty :=
  match T with
    | TVar b x => TVar b x (* free var remains free. functional, so we can't check for conflict *)
    | TVarB x => if beq_nat k x then u else TVarB x
    | TTop        => TTop
    | TBot        => TBot
    | TBool       => TBool
    | TSel T1     => TSel (open k u T1)                  
    | TFun T1 T2  => TFun (open k u T1) (open k u T2)
    | TMem T1 T2  => TMem (open k u T1) (open k u T2)
    | TBind T1    => TBind (open (S k) u T1)                          
  end.

Fixpoint subst (k: nat) (U : ty) (T : ty) {struct T} : ty :=
  match T with
    | TTop         => TTop
    | TBot         => TBot
    | TBool        => TBool
    | TMem T1 T2   => TMem (subst k U T1) (subst k U T2)
    | TSel T1      => TSel (subst k U T1)
    | TVarB i      => TVarB i
    | TVar true i  => TVar true i
    | TVar false i =>
      match nat_compare i k with
        | Lt => TVar false i
        | Eq => U
        | Gt => TVar false (i-1)
      end
    | TFun T1 T2   => TFun (subst k U T1) (subst k U T2)
    | TBind T2     => TBind (subst k U T2)
  end.

(*
Fixpoint nosubst (T : ty) {struct T} : Prop :=
  match T with
    | TTop         => True
    | TBot         => True
    | TBool        => True
    | TMem m T1 T2   => nosubst T1 /\ nosubst T2
    | TSel (varB i) m => True
    | TSel (varF i) m => True
    | TSel (varH i) m => i <> 0
    | TAll m T1 T2   => nosubst T1 /\ nosubst T2
    | TBind T2     => nosubst T2
    | TAnd T1 T2   => nosubst T1 /\ nosubst T2
    | TOr  T1 T2   => nosubst T1 /\ nosubst T2
  end.
*)



Inductive stp: tenv -> ty -> ty -> Prop :=
| stp_bot: forall G1 T,
    closed (length G1) 0 0  T ->
    stp G1 TBot T
| stp_top: forall G1 T,
    closed (length G1) 0 0 T ->
    stp G1 T TTop
| stp_bool: forall G1,
    stp G1 TBool TBool
| stp_fun: forall G1 T1 T2 T3 T4,
    stp G1 T3 T1 ->
    stp G1 T2 T4 ->
    stp G1 (TFun T1 T2) (TFun T3 T4)
| stp_mem: forall G1 T1 T2 T3 T4,
    stp G1 T3 T1 ->
    stp G1 T2 T4 ->
    stp G1 (TMem T1 T2) (TMem T3 T4)
| stp_varx: forall G1 x,
    x < length G1 ->
    stp G1 (TVar false x) (TVar false x)
(* | stp_vary: forall G1 x y,
    index x G1 = Some (TVar false y) ->
    y < length G1 ->
    stp G1 (TVar false y) (TVar false x) *)
| stp_var1: forall G1 x T1,
    index x G1 = Some T1 ->
    closed (length G1) 0 0 T1 ->
    stp G1 (TVar false x) T1
| stp_sel1: forall G1 T2 b x,
    stp G1 (TVar b x) (TMem TBot T2) ->
    stp G1 (TSel (TVar b x)) T2
| stp_sel2: forall G1 T1 b x,
    stp G1 (TVar b x) (TMem T1 TTop) ->
    stp G1 T1 (TSel (TVar b x))

.


Inductive stp2: nat -> bool -> tenv -> venv -> ty -> ty -> nat -> Prop :=
| stp2_bot: forall m GH G1 T n1,
    closed (length GH) (length G1) 0  T ->
    stp2 m true GH G1 TBot T (S n1)
| stp2_top: forall m GH G1 T n1,
    closed (length GH) (length G1) 0 T ->
    stp2 m true GH G1 T  TTop (S n1)
| stp2_bool: forall m GH G1 n1,
    stp2 m true GH G1 TBool TBool (S n1)
| stp2_fun: forall m GH G1 T1 T2 T3 T4 n1 n2,
    stp2 m false GH G1 T3 T1 n1 ->
    stp2 m false GH G1 T2 T4 n2 ->
    stp2 m true GH G1 (TFun T1 T2) (TFun T3 T4) (S (n1+n2))
| stp2_mem: forall m GH G1 T1 T2 T3 T4 n1 n2,
    stp2 m false GH G1 T3 T1 n2 ->
    stp2 m false GH G1 T2 T4 n1 ->
    stp2 m true GH G1 (TMem T1 T2) (TMem T3 T4) (S (n1+n2))


| stp2_varx: forall m GH G1 x n1,
    x < length G1 ->
    stp2 m true GH G1 (TVar true x) (TVar true x) (S n1)
| stp2_var1: forall m m2 GH G1 x T2 n1,
    vtp m2 G1 x T2 n1 -> (* slack for: val_type G2 v T2 *)
    stp2 m true GH G1 (TVar true x) T2 (S n1)

(* not sure if we should have these 2 or not ... ? *)
(*
| stp2_varb1: forall m GH G1 T2 x n1,
    stp2 m true GH G1 (TVar true x) (TBind T2) n1 -> 
    stp2 m true GH G1 (TVar true x) (open 0 (TVar false x) T2) (S n1) 

| stp2_varb2: forall m GH G1 T2 x n1,
    stp2 m true GH G1 (TVar true x) (open 0 (TVar false x) T2) n1 -> 
    stp2 m true GH G1 (TVar true x) (TBind T2) (S n1)
*)
    
(*| stp2_varax: forall m GH G1 x n1,
    x < length GH ->
    stp2 m true GH G1 (TVar false x) (TVar false x) (S n1) *)
(* | stp2_varay: forall m GH G1 TX x1 x2 n1,
    index x1 GH = Some TX ->
    stp2 m false GH G1 TX (TVar false x2) n1 ->
    stp2 m true GH G1 (TVar false x2) (TVar false x1) (S n1) *)
(* | stp2_vary: forall m GH G1 x1 x2 n1,
    index x1 GH = Some (TVar true x2) ->
    x2 < length G1 ->
    stp2 m true GH G1 (TVar true x2) (TVar false x1) (S n1) *)
| stp2_vara1: forall m GH GU G1 TX T2 x n1,
    index x GH = Some TX ->
    GH = GU ++ [TX] ->
    x = 0 -> 
    stp2 m false [TX] G1 TX T2 n1 -> (* TEMP -- SHOULD ALLOW UP TO x *)
    stp2 m true GH G1 (TVar false x) T2 (S n1)

| stp2_varab1: forall m GH G1 T2 x n1,
    stp2 m true GH G1 (TVar false x) (TBind T2) n1 -> 
    stp2 m true GH G1 (TVar false x) (open 0 (TVar false x) T2) (S n1) 

| stp2_varab2: forall m GH G1 T2 x n1,
    stp2 m true GH G1 (TVar false x) (open 0 (TVar false x) T2) n1 -> 
    stp2 (S m) true GH G1 (TVar false x) (TBind T2) (S n1)

| stp2_strong_sel1: forall m GH G1 T2 TX x n1,
    index x G1 = Some (vty TX) ->
    stp2 m false [] G1 TX T2 n1 ->
    stp2 m true GH G1 (TSel (TVar true x)) T2 (S n1)
| stp2_strong_sel2: forall m GH G1 T1 TX x n1,
    index x G1 = Some (vty TX) ->
    stp2 m false [] G1 T1 TX n1 ->
    stp2 m true GH G1 T1 (TSel (TVar true x)) (S n1)


| stp2_sel1: forall m GH G1 T2 x b n1,
    stp2 m true GH G1 (TVar b x) (TMem TBot T2) n1 ->
    stp2 m true GH G1 (TSel (TVar b x)) T2 (S n1)

| stp2_sel2: forall m GH G1 T1 b x n1,
    stp2 m true GH G1 (TVar b x) (TMem T1 TTop) n1 ->
    stp2 m true GH G1 T1 (TSel (TVar b x)) (S n1)


| stp2_bindx: forall m GH G1 T1 T1' T2 T2' n1,
    stp2 m false (T1'::GH) G1 T1' T2' n1 ->
    T1' = (open 0 (TVar false (length GH)) T1) ->
    T2' = (open 0 (TVar false (length GH)) T2) -> 
    stp2 (S m) true GH G1 (TBind T1) (TBind T2) (S n1)
         
         
| stp2_wrapf: forall m GH G1 T1 T2 n1,
    stp2 m true GH G1 T1 T2 n1 ->
    stp2 m false GH G1 T1 T2 (S n1)
| stp2_transf: forall m GH G1 T1 T2 T3 n1 n2 m2 m3,
    stp2 m false GH G1 T1 T2 n1 ->
    stp2 m2 false GH G1 T2 T3 n2 -> 
    stp2 m3 false GH G1 T1 T3 (S (n1+n2))
         

with wf_env : venv -> tenv -> Prop := 
| wfe_nil : wf_env nil nil
| wfe_cons : forall v t vs ts,
    val_type (v::vs) v t ->
    wf_env vs ts ->
    wf_env (cons v vs) (cons t ts)

with val_type0 : venv -> vl -> ty -> Prop :=
| v_bool: forall venv b,
    val_type0 venv (vbool b) TBool
| v_abs: forall venv T1 T2,
    val_type0 venv (vabs T1 T2) (TFun T1 T2)
| v_ty: forall venv T1,
    val_type0 venv (vty T1) (TMem T1 T1)
              
with val_type : venv -> vl -> ty -> Prop :=
| v_sub: forall G1 T1 T2 v,
    val_type0 G1 v T1 ->
    (exists n, stp2 0 true [] G1 T1 T2 n) ->
    val_type G1 v T2


with vtp : nat -> venv -> nat -> ty -> nat -> Prop :=
| vtp_top: forall m G1 x n1,
    x < length G1 ->
    vtp m G1 x TTop (S n1)
| vtp_bool: forall m G1 x b n1,
    index x G1 = Some (vbool b) ->
    vtp m G1 x (TBool) (S (n1))
| vtp_mem: forall m G1 x TX T1 T2 ms n1 n2,
    index x G1 = Some (vty TX) ->
    stp2 ms false [] G1 T1 TX n1 ->
    stp2 ms false [] G1 TX T2 n2 ->
    vtp m G1 x (TMem T1 T2) (S (n1+n2))
| vtp_bind: forall m G1 x T2 n1,
    vtp m G1 x (open 0 (TVar true x) T2) n1 ->
    vtp (S m) G1 x (TBind T2) (S (n1))
| vtp_sel: forall m G1 x y TX n1,
    index y G1 = Some (vty TX) ->
    vtp m G1 x TX n1 ->
    vtp m G1 x (TSel (TVar true y)) (S (n1))


with vtp2 : venv -> nat -> ty -> nat -> Prop :=
| vtp2_refl: forall G1 x n1,
    x < length G1 -> 
    vtp2 G1 x (TVar true x) (S n1)
| vtp2_down: forall m G1 x T n1,
    vtp m G1 x T n1 ->
    vtp2 G1 x T (S n1) 
| vtp2_sel: forall G1 x y TX n1,
    index y G1 = Some (vty TX) ->
    vtp2 G1 x TX n1 ->
    vtp2 G1 x (TSel (TVar true y)) (S (n1)).
              


Definition stpd2 m b GH G1 T1 T2 := exists n, stp2 m b GH G1 T1 T2 n.

Definition vtpd m G1 x T1 := exists n, vtp m G1 x T1 n.
Definition vtpd2 G1 x T1 := exists n, vtp2 G1 x T1 n.

Definition vtpdd m G1 x T1 := exists m1 n, vtp m1 G1 x T1 n /\ m1 <= m.

Hint Constructors stp2.
Hint Constructors vtp.

Ltac ep := match goal with
             | [ |- stp2 ?M ?B ?GH ?G1 ?T1 ?T2 ?N ] => assert (exists (n:nat), stp2 M B GH G1 T1 T2 n) as EEX
           end.

Ltac eu := match goal with
             | H: stpd2 _ _ _ _ _ _ |- _ => destruct H as [? H]
             | H: vtpd _ _ _ _ |- _ => destruct H as [? H]
             | H: vtpd2 _ _ _ |- _ => destruct H as [? H]
             | H: vtpdd _ _ _ _ |- _ => destruct H as [? [? [H ?]]]
           end.

Lemma stpd2_bot: forall m GH G1 T,
    closed (length GH) (length G1) 0 T ->
    stpd2 m true GH G1 TBot T.
Proof. intros. exists 1. eauto. Qed.
Lemma stpd2_top: forall m GH G1 T,
    closed (length GH) (length G1) 0 T ->
    stpd2 m true GH G1 T TTop.
Proof. intros. exists 1. eauto. Qed.
Lemma stpd2_bool: forall m GH G1,
    stpd2 m true GH G1 TBool TBool.
Proof. intros. exists 1. eauto. Qed.
Lemma stpd2_fun: forall m GH G1 T1 T2 T3 T4,
    stpd2 m false GH G1 T3 T1 ->
    stpd2 m false GH G1 T2 T4 ->
    stpd2 m true  GH G1 (TFun T1 T2) (TFun T3 T4).
Proof. intros. repeat eu. eexists. eauto. Qed.
Lemma stpd2_mem: forall m GH G1 T1 T2 T3 T4,
    stpd2 m false GH G1 T3 T1 ->
    stpd2 m false GH G1 T2 T4 ->
    stpd2 m true  GH G1 (TMem T1 T2) (TMem T3 T4).
Proof. intros. repeat eu. eexists. eauto. Qed.

(*
Lemma stpd2_varx: forall m GH G1 x,
    x < length G1 ->                    
    stpd2 m true GH G1 (TVar true x) (TVar true x).
Proof. intros. repeat eu. exists 1. eauto. Qed.
Lemma stpd2_var1: forall m GH G1 TX x T2 v,
    index x G1 = Some v ->
    val_type0 G1 v TX -> (* slack for: val_type G2 v T2 *)
    stpd2 m true GH G1 TX T2 ->
    stpd2 m true GH G1 (TVar true x) T2.
Proof. intros. repeat eu. eexists. eauto. Qed.
(*Lemma stpd2_var1b: forall m GH G1 GX TX G2 x x2 T2 v,
    index x G1 = Some v ->
    index x2 G2 = Some v ->
    val_type0 GX v TX -> (* slack for: val_type G2 v T2 *)
    stpd2 m true GH GX TX G2 (open 0 (TVar true x2) T2) ->
    stpd2 m true GH G1 (TVar true x) G2 (TBind T2).
Proof. intros. repeat eu. eexists. eauto. Qed.*)
Lemma stpd2_sel: forall m GH G1 T1 T2,
    stpd2 m false GH G1 T2 T1 ->
    stpd2 m true  GH G1 T1 T2 ->
    stpd2 m true  GH G1 (TSel T1) (TSel T2).
Proof. intros. repeat eu. eexists. eauto. Qed.
Lemma stpd2_red: forall m GH G1 T1 T2,
    stpd2 m true GH G1 T1 (TMem TBot T2) ->
    stpd2 m true GH G1 (TSel T1) T2.
Proof. intros. repeat eu. eexists. eauto. Qed.
Lemma stpd2_red2: forall m GH G1 TX T1 T2 T0,
    real T0 ->
    stpd2 m true GH G1 T0 T2 ->
    stpd2 m false GH G1 T2 (TMem TX TTop) ->
    stpd2 m true GH G1 T0 (TMem TX TTop) ->
    stpd2 m false GH G1 T1 TX ->
    stpd2 m true GH G1 T1 (TSel T2).
Proof. intros. repeat eu. eexists. eauto. Qed.

(*
Lemma stpd2_bindI: forall G1 G2 T2 x,
    stpd2 true G1 (TVar x) G2 (open 0 (TVar x) T2) ->
    stpd2 true G1 (TVar x) G2 (TBind T2).
Proof. intros. repeat eu. eexists. eauto. Qed. *

Lemma stpd2_bindE: forall G1 G2 T2 x,
    stpd2 true G1 (TVar x) G2 (TBind T2) ->
    stpd2 true G1 (TVar x) G2 (open 0 (TVar x) T2).
Proof. intros. repeat eu. eexists. eauto. Qed.
*)

(*Lemma stpd2_bind1: forall m GH G1 T1 T2,
    closed (length GH) (length G2) 0 T2 ->
    stpd2 m true ((G1,(open 0 (TVar false (length GH)) T1))::GH)
          G1 (TVar false (length GH)) G2 T2 ->
    stpd2 m true GH G1 (TBind T1) G2 T2.
Proof. intros. repeat eu. eexists. eauto. Qed.
*)

*)

Lemma stpd2_wrapf: forall m GH G1 T1 T2,
    stpd2 m true GH G1 T1 T2 ->
    stpd2 m false GH G1 T1 T2.
Proof. intros. repeat eu. eexists. eauto. Qed.
Lemma stpd2_transf: forall m GH G1 T1 T2 T3,
    stpd2 m false GH G1 T1 T2 ->
    stpd2 m true GH G1 T2 T3 ->
    stpd2 m false GH G1 T1 T3.
Proof. intros. repeat eu. eexists. eauto. Qed.



Hint Constructors ty.
Hint Constructors vl.


Hint Constructors stp2.
Hint Constructors val_type.
Hint Constructors wf_env.

Hint Unfold stpd2.

Hint Constructors option.
Hint Constructors list.

Hint Unfold index.
Hint Unfold length.

Hint Resolve ex_intro.


Ltac ev := repeat match goal with
                    | H: exists _, _ |- _ => destruct H
                    | H: _ /\  _ |- _ => destruct H
           end.





Lemma wf_length : forall vs ts,
                    wf_env vs ts ->
                    (length vs = length ts).
Proof.
  intros. induction H. auto.
  assert ((length (v::vs)) = 1 + length vs). constructor.
  assert ((length (t::ts)) = 1 + length ts). constructor.
  rewrite IHwf_env in H1. auto.
Qed.

Hint Immediate wf_length.

Lemma index_max : forall X vs n (T: X),
                       index n vs = Some T ->
                       n < length vs.
Proof.
  intros X vs. induction vs.
  Case "nil". intros. inversion H.
  Case "cons".
  intros. inversion H.
  case_eq (beq_nat n (length vs)); intros E.
  SCase "hit".
  rewrite E in H1. inversion H1. subst.
  eapply beq_nat_true in E. 
  unfold length. unfold length in E. rewrite E. eauto.
  SCase "miss".
  rewrite E in H1.
  assert (n < length vs). eapply IHvs. apply H1.
  compute. eauto.
Qed.

Lemma index_exists : forall X vs n,
                       n < length vs ->
                       exists (T:X), index n vs = Some T.
Proof.
  intros X vs. induction vs.
  Case "nil". intros. inversion H.
  Case "cons".
  intros. inversion H.
  SCase "hit".
  assert (beq_nat n (length vs) = true) as E. eapply beq_nat_true_iff. eauto.
  simpl. subst n. rewrite E. eauto.
  SCase "miss".
  assert (beq_nat n (length vs) = false) as E. eapply beq_nat_false_iff. omega.
  simpl. rewrite E. eapply IHvs. eauto.
Qed.


Lemma index_extend : forall X vs n a (T: X),
                       index n vs = Some T ->
                       index n (a::vs) = Some T.

Proof.
  intros.
  assert (n < length vs). eapply index_max. eauto.
  assert (n <> length vs). omega.
  assert (beq_nat n (length vs) = false) as E. eapply beq_nat_false_iff; eauto.
  unfold index. unfold index in H. rewrite H. rewrite E. reflexivity.
Qed.


Lemma closed_extend : forall T X (a:X) i k G,
                       closed i (length G) k T ->
                       closed i (length (a::G)) k T.
Proof.
  intros T. induction T; intros; inversion H;  econstructor; eauto.
  simpl. omega.
Qed.

(*
Lemma stp2_extend : forall m b GH  v1 G1 G2 T1 T2 n,
                      stp2 m b GH G1 T1 G2 T2 n ->
                      stp2 m b GH (v1::G1) T1 G2 T2 n /\
                      stp2 m b GH G1 T1 (v1::G2) T2 n /\
                      stp2 m b GH (v1::G1) T1 (v1::G2) T2 n.
Proof.
  intros. induction H; try solve [repeat split; econstructor; try eauto;
          try eapply index_extend; eauto; try eapply closed_extend; eauto;
          try eapply IHstp2; eauto;
          try eapply IHstp2_1; try eapply IHstp2_2;
            try eapply IHstp2_3; try eapply IHstp2_4].
(*
  repeat split; eapply stp2_var1b. eapply index_extend; eauto. eauto. eauto.
  eauto. eauto. eapply index_extend; eauto. eauto. eapply IHstp2. eapply index_extend; eauto.
  eapply index_extend; eauto. eauto.
  eapply IHstp2.
*)
  admit. (* bind1 *)
  admit.
  admit.
  
  repeat split; eapply stp2_transf; try eapply IHstp2_1; eauto; try eapply IHstp2_2; eauto.
Qed.

Lemma stpd2_extend : forall m b GH v1 G1 G2 T1 T2,
                      stpd2 m b GH G1 T1 G2 T2 ->
                      stpd2 m b GH (v1::G1) T1 G2 T2 /\
                      stpd2 m b GH G1 T1 (v1::G2) T2 /\
                      stpd2 m b GH (v1::G1) T1 (v1::G2) T2.
Proof.
  intros. repeat eu. repeat split; eexists; eapply stp2_extend; eauto.
Qed.


Lemma stp2_extend1 : forall m b GH v1 G1 G2 T1 T2 n, stp2 m b GH G1 T1 G2 T2 n -> stp2 m b GH (v1::G1) T1 G2 T2 n.
Proof. intros. eapply stp2_extend. eauto. Qed.

Lemma stp2_extend2 : forall m b GH v1 G1 G2 T1 T2 n, stp2 m b GH G1 T1 G2 T2 n -> stp2 m b GH G1 T1 (v1::G2) T2 n.
Proof. intros. eapply stp2_extend. eauto. Qed.

Lemma stpd2_extend1 : forall m b GH v1 G1 G2 T1 T2, stpd2 m b GH G1 T1 G2 T2 -> stpd2 m b GH (v1::G1) T1 G2 T2.
Proof. intros. eapply stpd2_extend. eauto. Qed.

Lemma stpd2_extend2 : forall m b GH v1 G1 G2 T1 T2, stpd2 m b GH G1 T1 G2 T2 -> stpd2 m b GH G1 T1 (v1::G2) T2.
Proof. intros. eapply stpd2_extend. eauto. Qed.
*)


Lemma stp_closed : forall G1 T1 T2,
                      stp G1 T1 T2 ->
                      closed (length G1) 0 0 T1 /\
                      closed (length G1) 0 0 T2.
Proof.
 admit. (*   intros. induction H; repeat split; try  econstructor; try eapply IHstp1; try eapply IHstp2; eauto; try eapply IHstp; eauto; try eapply index_max; eauto.
  destruct IHstp. inversion H1. eauto.
    destruct IHstp. inversion H1. eauto. *)

Qed.



Lemma stpd2_closed : forall m b GH G1 T1 T2,
                      stpd2 m b GH G1 T1 T2 ->
                      closed (length GH) (length G1) 0 T1 /\
                      closed (length GH) (length G1) 0 T2.
Proof.
  admit. (*
  intros. eu. induction H; repeat split; try  econstructor; try eapply IHstp2_1; try eapply IHstp2_2; eauto; try eapply IHstp2; eauto; try eapply index_max; eauto.
  destruct IHstp2. inversion H1. eauto.
  eapply IHstp2_4. *)
  
Qed.

Lemma stpd2_closed1 : forall m b GH G1 T1 T2,
                      stpd2 m b GH G1 T1 T2 ->
                      closed (length GH) (length G1) 0 T1.
Proof. intros. eapply (stpd2_closed m b GH G1 T1 T2); eauto. Qed.

Lemma stpd2_closed2 : forall m b GH G1 T1 T2,
                      stpd2 m b GH G1 T1 T2 ->
                      closed (length GH) (length G1) 0 T2.
Proof. intros. eapply (stpd2_closed m b GH G1); eauto. Qed.


Lemma valtp_extend : forall vs v v1 T,
                       val_type vs v T ->
                       val_type (v1::vs) v T.
Proof.
  admit.
  (*intros. induction H; econstructor; eauto; try eapply stpd2_extend; eauto; try eapply index_extend; eauto. 
   *)
Qed.



Lemma index_safe_ex: forall H1 G1 TF i,
             wf_env H1 G1 ->
             index i G1 = Some TF ->
             exists v, index i H1 = Some v /\ val_type H1 v TF.
Proof. intros. induction H.
       Case "nil". inversion H0.
       Case "cons". inversion H0.
         case_eq (beq_nat i (length ts)).
           SCase "hit".
             intros E.
             rewrite E in H3. inversion H3. subst t.
             assert (beq_nat i (length vs) = true). eauto.
             assert (index i (v :: vs) = Some v). eauto.  unfold index. rewrite H2. eauto.
             eauto.
           SCase "miss".
             intros E.
             assert (beq_nat i (length vs) = false). eauto.
             rewrite E in H3.
             assert (exists v0, index i vs = Some v0 /\ val_type vs v0 TF) as HI. eapply IHwf_env. eauto.
           inversion HI as [v0 HI1]. inversion HI1. 
           eexists. econstructor. eapply index_extend; eauto. eapply valtp_extend; eauto.
Qed.

  

Lemma stpd2_refl: forall m GH G1 T1,
  closed (length GH) (length G1) 0 T1 ->
  stpd2 m true GH G1 T1 T1.
Proof.
admit. (*  intros. induction T1; inversion H.
  - Case "bot". exists 1. eauto.
  - Case "top". exists 1. eauto.
  - Case "bool". eapply stpd2_bool; eauto.
  - Case "fun". eapply stpd2_fun; try eapply stpd2_wrapf; eauto.
  - Case "var0". exists 1. eauto. 
  - Case "var1".
    assert (exists v, index i G1 = Some v) as E. eapply index_exists; eauto.
    destruct E.
    eapply stpd2_varx; eauto.
  - Case "varb". inversion H4. 
  - Case "mem". eapply stpd2_mem; try eapply stpd2_wrapf; eauto.
  - Case "sel". eapply stpd2_sel; try eapply stpd2_wrapf; eauto.
  - Case "bind".
    admit.
    
    (* don't have index & val_type0 evidence *)
    
    (*exists 3. eapply stp2_bind1. eauto. 
    eapply stp2_bind2.
    simpl. eauto.

    eapply stp2_vara1. simpl. rewrite <-beq_nat_refl. eauto. *)
    
    (* TODO: 
       stp2 m true ((G1, open 0 (TVar false (length GH)) T1) :: GH) G1
     (open 0 (TVar false (length GH)) T1) G1
     (open 0 (TVar false (length GH)) T1) 0
     *)*)
Qed.

Lemma stpd2_reg1 : forall m b GH G1 T1 T2,
                      stpd2 m b GH G1 T1 T2 ->
                      stpd2 m true GH G1 T1 T1.
Proof.
  intros. eapply stpd2_refl. eapply (stpd2_closed m b GH G1 T1 T2). eauto.
Qed.

Lemma stpd2_reg2 : forall m b GH G1 T1 T2,
                      stpd2 m b GH G1 T1 T2 ->
                      stpd2 m true GH G1 T2 T2.
Proof.
  intros. eapply stpd2_refl. eapply (stpd2_closed m b GH G1). eauto.
Qed.

(*

Lemma invert_bind1: forall n, forall venv vf T1 GX TX n1,
  val_type0 GX vf TX -> stp2 true GX TX venv (TBind T1) n1 -> n1 < n ->
  exists x n2,
    index x venv = Some vf ->
    n2 < n1 ->
    stp2 true GX TX venv (open 0 (TVar x) T1) n2.
Proof.
  intros n. induction n; intros. solve by inversion.
  inversion H; subst. 
  - Case "bool". solve by inversion.
  - Case "fun". solve by inversion.
(*   - Case "var". subst. inversion H0; subst.
    + SCase "normal".
    assert (vf = v) as A. rewrite H2 in H4. inversion H4. eauto.
    rewrite A. assert (n0 < n) as B. omega. 
    specialize (IHn venv0 v T1 GX0 TX n0 H5 H6 B).
    ev. repeat eexists; eauto. 
  (* repeat eapply IHn; eauto. omega. *)
    + SCase "bindE". eauto.
    + eauto.      *)
  - Case "mem". solve by inversion.
Qed.
*)


Lemma stp2_downgrade: forall m m2 b GH G1 T1 T2 n1,
  stp2 m b GH G1 T1 T2 n1 -> m <= m2 ->
  stp2 m2 b GH G1 T1 T2 n1.
Proof.
  admit.
Qed.

(*
Lemma stpd2_trans_axiom_aux: forall n, forall m m2 GH G1 T1 T2 T3 n1,
  stpd2 m false GH G1 T1 T2 -> 
  stp2 m2 false GH G1 T2 T3 n1 -> n1 < n -> m2 <= m ->
  stpd2 m2 false GH G1 T1 T3.
Proof.
  intros n. induction n; intros; try omega; repeat eu; subst; inversion H0; clear H0; subst.
  - Case "wrapf". eexists. eapply stp2_transf. eauto. eauto. eauto. 
  - Case "transf".
    assert (m = m2 + (m - m2)). omega.
    assert (stpd2 m false GH G1 T1 T4). eapply IHn. eauto. rewrite H0. eapply stp2_downgrade. eauto. eapply stp2_downgrade. eauto. omega. eauto. 
    eu. eexists. eapply stp2_transf. eauto. eauto. omega. 
Qed.



Lemma stp2_trans_axiom: forall m b GH G1 T1 T2 T3,
  stpd2 m false GH G1 T1 T2 -> 
  stpd2 m b GH G1 T2 T3 ->
  stpd2 m false GH G1 T1 T3.
Proof.
  intros. destruct b; eu; eu; eapply stpd2_trans_axiom_aux; eauto.
Qed.
*)


Ltac index_subst := match goal with
                      | H1: index ?x ?G = ?V1 , H2: index ?x ?G = ?V2 |- _ => rewrite H1 in H2; inversion H2; subst
                      | _ => idtac
                    end.

Ltac invty := match goal with
                | H1: TBot     = _ |- _ => inversion H1
                | H1: TBool    = _ |- _ => inversion H1
                | H1: TSel _   = _ |- _ => inversion H1
                | H1: TMem _ _ = _ |- _ => inversion H1
                | H1: TVar _ _ = _ |- _ => inversion H1
                | H1: TFun _ _ = _ |- _ => inversion H1
                | H1: TBind  _ = _ |- _ => inversion H1
                | _ => idtac
              end.

Ltac invstp_var := match goal with
  | H1: stp2 _ true _ _ TBot        (TVar _ _) _ |- _ => inversion H1
  | H1: stp2 _ true _ _ TTop        (TVar _ _) _ |- _ => inversion H1
  | H1: stp2 _ true _ _ TBool       (TVar _ _) _ |- _ => inversion H1
  | H1: stp2 _ true _ _ (TFun _ _)  (TVar _ _) _ |- _ => inversion H1
  | H1: stp2 _ true _ _ (TMem _ _)  (TVar _ _) _ |- _ => inversion H1
  | H1: val_type0 _ _ _ |- _ => inversion H1
  | _ => idtac
end.



Lemma closed_no_subst: forall T i j k TX,
   closed i j k T ->
   subst i TX T = T.
Proof.
  admit.
(*  intros T. induction T; intros; inversion H; simpl; eauto;
    try rewrite (IHT (S j) TX); eauto;
    try rewrite (IHT2 (S j) TX); eauto;
    try rewrite (IHT j TX); eauto;
    try rewrite (IHT1 j TX); eauto;
    try rewrite (IHT2 j TX); eauto.

  eapply closed_upgrade. eauto. eauto.
  subst. omega.
  subst. eapply closed_upgrade. eassumption. omega.
  subst. eapply closed_upgrade. eassumption. omega. *)
Qed.

(*
Lemma subst_open_commute: forall i j n V l T2, closed i (n+1) (j+1) (n+1) T2 -> closed 0 0 (TSel V l) ->
    subst V (open_rec j (varH (n+1)) T2) = open_rec j (varH n) (subst V T2).
Proof.
  intros. eapply subst_open_commute_m; eauto.
Qed.
*)

(* FIXME: need some closed evidence, but don't worry about it for now *)

Lemma subst_open_commute: forall T0 TX n,
  (subst n TX (open 0 (TVar false n) T0)) = open 0 TX T0.
Proof. admit. Qed.


Lemma subst_open_commute1: forall T0 x x0,
 (open 0 (TVar true x0) (subst 0 (TVar true x) T0)) 
 = (subst 0 (TVar true x) (open 0 (TVar true x0) T0)).
Proof. admit. Qed.


(*
Lemma stp2_subst: forall m b GH G1 T1 T2 TX n1,
   stp2 m b (TX::GH) G1 T1 T2 n1 ->
   stpd2 m b GH G1 (subst (length GH) TX T1) (subst (length GH) TX T2).
Proof.
  admit.
Qed.
*)


(* THIS WILL NOT WORK !!! *)
(* using stp2_transf, we increase the size to m recursively *)

(* IDEA: do not support trans for bindx, by making stp2_trans
   work only for T1 = mem, fun, var.
   Is that sufficient for induction? ---> probably yes
*)

Lemma stp2_narrow: forall m m2 b GH TX1 TX2 G1 T1 T2 n1 n2,
  stp2 m false (TX1::GH) G1 TX1 TX2 n1 ->
  stp2 m2 b (TX2::GH) G1 T1 T2 n2 -> m2 <= m ->
  stpd2 m2 b (TX1::GH) G1 T1 T2.
Proof.
  admit.
Qed.

Definition substt x T := (subst 0 (TVar true x) T).


Lemma closed_subst: forall i j k x T2,
  closed (i + 1) j k T2 ->
  closed i j k (substt x T2).
Proof. admit. Qed.



Lemma stp2_subst_narrow0: forall n, forall m2 b GH G1 T1 T2 TX x n2,
   stp2 m2 b (GH++[TX]) G1 T1 T2 n2 -> n2 < n ->
   (forall (m1 : nat) GH (T3 : ty) (n1 : nat),
      stp2 m1 true (GH++[TX]) G1 (TVar false 0) T3 n1 -> n1 < n ->
      exists m2, vtpd m2 G1 x (substt x T3)) ->
   stpd2 m2 b (map (substt x) GH) G1 (substt x T1) (substt x T2).
Proof.
  intros n. induction n. intros. omega.
  intros.
  inversion H.
  - Case "bot". subst.
    eapply stpd2_bot; eauto. rewrite map_length. simpl. eapply closed_subst. rewrite app_length in H2. simpl in H2. eapply H2.
  - Case "top". subst.
    eapply stpd2_top; eauto. rewrite map_length. simpl. eapply closed_subst. rewrite app_length in H2. simpl in H2. eapply H2.
  - Case "bool". subst.
    eapply stpd2_bool; eauto.
  - Case "fun". subst.
    eapply stpd2_fun. eapply IHn; eauto. omega. eapply IHn; eauto. omega.
  - Case "mem". subst.
    eapply stpd2_mem. eapply IHn; eauto. omega. eapply IHn; eauto. omega.

  - Case "varx". subst.
    eexists. eapply stp2_varx. eauto.
  - Case "var1". subst.
    assert (substt x T2 = T2) as R. admit. (* closed *)
    eexists. eapply stp2_var1. rewrite R. eauto.
  - Case "vara1". 
    case_eq (beq_nat x0 0); intros E.
    + (* hit *)
      assert (x0 = 0). eauto. 
      assert (exists m0, vtpd m0 G1 x (substt x T2)). subst. eapply H1; eauto.
      ev. eu. subst. repeat eexists. simpl. eapply stp2_var1. eauto. 
    + (* miss *)
      subst. inversion E. (* not now *)
  - Case "varab1".
    case_eq (beq_nat x0 0); intros E.
    + (* hit *)
      assert (x0 = 0). eapply beq_nat_true_iff; eauto. 
      assert (exists m0, vtpd m0 G1 x (substt x (TBind T0))). subst. eapply H1; eauto. omega. 
      assert ((subst 0 (TVar true x) T0) = T0) as R. admit. (* closed! *)
      ev. eu. inversion H11. rewrite R in H16. clear R. subst.
      repeat eexists. eapply stp2_var1. unfold substt. rewrite subst_open_commute. eauto. 
    + (* miss *)
      assert (stpd2 m2 true (map (substt x) GH) G1 (substt x (TVar false x0))
         (substt x (TBind T0))). eapply IHn; eauto. omega. 
      assert (substt x (TBind T0) = TBind (substt x T0)) as R1. admit.
      assert (substt x (open 0 (TVar false x0) T0) = open 0 (TVar false x0) (substt x T0)) as R2. admit.
      assert (substt x (TVar false x0) = (TVar false x0)) as R3. admit. 
      rewrite R2. rewrite R3. eu. repeat eexists. eapply stp2_varab1. rewrite <-R3. rewrite <-R1. eauto.
  - Case "varab2".
    case_eq (beq_nat x0 0); intros E.
    + (* hit *)
      assert (x0 = 0). eapply beq_nat_true_iff; eauto. subst x0. 
      assert (exists m0, vtpd m0 G1 x (substt x (open 0 (TVar false 0) T0))). subst. eapply H1; eauto. omega. 
      assert ((subst 0 (TVar true x) T0) = T0) as R. admit. (* closed! *)
      ev. eu. unfold substt in H10. rewrite subst_open_commute in H10. 
      repeat eexists. unfold substt. simpl. eapply stp2_var1. eapply vtp_bind. eauto.
      rewrite R. eauto. 
    + (* miss *)
      assert (stpd2 m true (map (substt x) GH) G1 (substt x (TVar false x0))
         (substt x (open 0 (TVar false x0) T0))). eapply IHn; eauto. omega. 
      assert (substt x (TBind T0) = TBind (substt x T0)) as R1. admit.
      assert (substt x (open 0 (TVar false x0) T0) = open 0 (TVar false x0) (substt x T0)) as R2. admit.
      assert (substt x (TVar false x0) = (TVar false x0)) as R3. admit. 
      rewrite R3. rewrite R1. eu. repeat eexists. eapply stp2_varab2.
      rewrite R3 in H10. rewrite R2 in H10. eauto.

  - Case "ssel1". subst. 
    assert (substt x T2 = T2) as R. admit. (* closed! *)
    eexists. eapply stp2_strong_sel1. eauto. rewrite R. eauto. 
    
  - Case "ssel2". subst. 
    assert (substt x T1 = T1) as R. admit. (* closed! *)
    eexists. eapply stp2_strong_sel2. eauto. rewrite R. eauto. 

  - Case "sel1". subst. (* alternative: could create strong_sel node *)
    assert (stpd2 m2 true (map (substt x) GH) G1 (substt x ((TVar b0 x0))) (TMem TBot (substt x T2))). admit. 
    eu. eexists. destruct b0.
    simpl. eapply stp2_sel1. unfold substt in H3 at 2. simpl in H3. eapply H3.
    simpl. unfold substt at 2. unfold substt at 2 in H3. simpl in H3. simpl. destruct (nat_compare x0 0); eapply stp2_sel1; unfold substt in H3 at 2; simpl in H3; eapply H3. 

  - Case "sel2". subst. (* alternative: could create strong_sel node *)
    assert (stpd2 m2 true (map (substt x) GH) G1 (substt x ((TVar b0 x0))) (TMem (substt x T1) TTop)). admit. 
    eu. eexists. destruct b0.
    simpl. eapply stp2_sel2. unfold substt in H3 at 2. simpl in H3. eapply H3.
    simpl. unfold substt at 3. unfold substt at 2 in H3. simpl in H3. simpl. destruct (nat_compare x0 0); eapply stp2_sel2; unfold substt in H3 at 2; simpl in H3; eapply H3. 
    
  - Case "bindx".
    assert (stpd2 m false (map (substt x) (T1'::GH)) G1 (substt x T1')
     (substt x T2')). eapply IHn; eauto. omega. 
    eu. repeat eexists. eapply stp2_bindx. eauto. admit. admit. (* open / subst *)

  - Case "wrapf".
    assert (stpd2 m2 true (map (substt x) GH) G1 (substt x T1) (substt x T2)).
    eapply IHn; eauto. omega.
    eu. repeat eexists. eapply stp2_wrapf. eauto. 
  - Case "transf". 
    assert (stpd2 m false (map (substt x) GH) G1 (substt x T1) (substt x T3)).
    eapply IHn; eauto. omega.
    assert (stpd2 m0 false (map (substt x) GH) G1 (substt x T3) (substt x T2)).
    eapply IHn; eauto. omega.
    eu. eu. repeat eexists. eapply stp2_transf. eauto. eauto. 
    
Grab Existential Variables.
apply 0. 
Qed. 


Lemma stp2_subst_narrowX: forall ml, forall nl, forall m m2 GH G1 T2 TX x n1 n2,
   vtp m G1 x (substt x TX) n1 ->
   stp2 m2 true (GH++[TX]) G1 (TVar false 0) T2 n2 -> m < ml -> n2 < nl ->
   (forall (m1 : nat) (b : bool) (G1 : venv) x (T2 T3 : ty) (n1 n2 : nat),
        vtp m G1 x T2 n1 ->
        stp2 m1 b [] G1 T2 T3 n2 ->
        vtpdd m G1 x T3) ->
   exists m1, vtpd m1 G1 x (substt x T2). (* XXX if transitivity, then would need to decrease b/c *)
Proof. 
  intros ml. (* induction ml. intros. omega. *)
  intros nl. induction nl. intros. omega.
  intros.
  inversion H0.
  - Case "top". subst.
    repeat eexists. eapply vtp_top; eauto. admit. 
  - Case "vara1". subst.
    assert (TX = TX0). admit.
    subst TX0.
    assert (GH = GU). admit.
    subst GU.
    (* RHS via induction (non-var case) *)
    assert (stpd2 (m2) false (map (substt x) []) G1 (substt x TX) (substt x T2)) as RHS.
    eapply stp2_subst_narrow0. eauto. eauto. simpl.
    { intros. subst. eapply IHnl. eauto. eauto. eauto. omega.
    eauto. }
    destruct RHS as [nr RHS].
    (* transitivity *)
    assert (vtpdd m G1 x (substt x T2)) as BB.
    unfold substt. simpl. eapply H3. (* trans *) eapply H. eapply RHS.
    (* return *)
    eu. repeat eexists. eauto. 
  - Case "varab1". subst.
    assert (exists m1, vtpd m1 G1 x (substt x (TBind T0))) as A.
    eapply IHnl. eauto. eauto. eauto. omega. eauto.
    destruct A as [? A]. eu. inversion A. subst.
    assert ((subst 0 (TVar true x) T0) = T0) as R. admit. (* closed! *)
    rewrite R in H9. unfold substt. rewrite subst_open_commute. 
    repeat eexists. eapply H9.
  - Case "varab2". subst.
    assert (exists m1, vtpd m1 G1 x (substt x (open 0 (TVar false 0) T0))) as A.
    eapply IHnl. eauto. eauto. eauto. omega. eauto.
    assert ((subst 0 (TVar true x) T0) = T0) as R. admit. (* closed! *)
    unfold substt in A. rewrite subst_open_commute in A.
    unfold substt. simpl. rewrite R.
    destruct A as [? A]. eu. repeat eexists. eapply vtp_bind. eapply A.
  - Case "ssel". subst.
    (* XXX can't happen, b/c we require GH = [] *)
    (* XXX otherwise we'd need to support stp false, because that's what we get from mem inv *)
    assert (closed (length ([]:tenv)) (length G1) 0 (TVar false 0)). eapply stpd2_closed1.
    eexists. eapply H5. simpl in H6. inversion H6. omega. 
 (*     
    assert ((subst 0 (TVar true x) TX0) = TX0) as R. admit. (* closed *)
    assert (vtpdd m G1 x (substt x TX0)).
    eapply IHnl. eauto. eauto. eauto. omega. eauto. 
    eu. repeat eexists. eapply vtp_sel. eauto. unfold substt in H6. rewrite R in H6. eapply H6. eauto.*)

    (* XXX in the general case, we may need to deal with (TSel (TVar false x)), too *)

  - Case "sel". subst.
    destruct b.
    + (* true -- this is the same as strong_sel_2*)
      inversion H4. subst. inversion H7. subst.
      assert (closed (length ([]:tenv)) (length G1) 0 (TVar false 0)). eapply stpd2_closed1.
      eexists. eapply H12. simpl in H5. inversion H5. omega.
    + (* false -- must be x0 = 0 ??? *)
      case_eq (beq_nat x0 0); intros E.
      * assert (x0 = 0). eapply beq_nat_true_iff. eauto.
        subst.
        assert (exists m1 : nat, vtpd m1 G1 x (substt x (TMem (TVar false 0) TTop))).
        eapply IHnl; eauto. omega.
        ev. eu. inversion H5. subst.
        assert (exists m n, vtp m G1 x TX0 n). admit.
        (* XXX TODO: 

           ----> PROBLEM <----

           It seems like we need access stp_trans2. 
           But do we have the right size?
           Or can we somehow rule out this case?
        *)
        ev. ev. repeat eexists. eapply vtp_sel. eauto. eauto.
      * admit.
        (* XXX TODO:
           This means we have (TVar false x0) < (TMem (TVar false 0) TTop)  and x0 > 0.
           There does not seem to be away to create a vtp instance for this!!

           ----> PROBLEM <----

           Idea: limit all rules (TVar false x0) < ... to GH = [TX]
         *)

(* - Case "wrapf" *)
(* - Case "transf" *)        
        
        (* Transf not supported. Difficult:
           (1) LHS vtp does not shrink due to bind-intro rule
           (2) RHS does not shrink since it needs to pass 
               through subst_narrow0 which may increase size
        *)
        
Grab Existential Variables.
    apply 0. apply 0.
Qed.

(*

(* TODO: need to be careful will m1 and m2 !!! *)
Lemma stp2_subst_narrow: forall ml, forall nl, forall m m2 b GH G1 T1 T2 TX x n1 n2,
   vtp m G1 x (substt x TX) n1 ->
   stp2 m2 b (GH++[TX]) G1 T1 T2 n2 -> m < ml -> n2 < nl ->
   (forall (m1 : nat) (b : bool) (G1 : venv) x (T2 T3 : ty) (n1 n2 : nat),
        vtp m G1 x T2 n1 ->
        stp2 m1 b [] G1 T2 T3 n2 ->
        vtpdd m G1 x T3) ->
   stpd2 m2 b (map (substt x) GH) G1 (substt x T1) (substt x T2).
Proof.
  intros ml. (* induction ml. intros. omega. *)
  intros nl. induction nl. intros. omega.
  intros.
  inversion H0.
  - Case "bot". subst.
    eapply stpd2_bot; eauto. rewrite map_length. simpl. eapply closed_subst. rewrite app_length in H4. simpl in H4. eapply H4.
  - Case "top". subst.
    eapply stpd2_top; eauto. rewrite map_length. simpl. eapply closed_subst. rewrite app_length in H4. simpl in H4. eapply H4.
  - Case "bool". subst.
    eapply stpd2_bool; eauto.
  - Case "fun". subst.
    eapply stpd2_fun. eapply IHnl; eauto. omega. eapply IHnl; eauto. omega.
  - Case "mem". subst.
    eapply stpd2_mem. eapply IHnl; eauto. omega. eapply IHnl; eauto. omega.

  - Case "varx". subst.
    eexists. eapply stp2_varx. eauto.
  - Case "var1". subst.
    assert (substt x T2 = T2). admit. (* closed *)
    eexists. eapply stp2_var1. rewrite H5. eauto.
(*  - Case "varb1". subst. admit.
  - Case "varb2". subst. admit. *)
  - Case "vara1". 
    case_eq (beq_nat x0 0); intros E.
    + SCase "hit". 
      eapply beq_nat_true_iff in E. subst x0.
      assert (TX = TX0). admit.
      subst TX0.
      (* RHS via induction *)
      assert (stpd2 (m2) false (map (substt x) []) G1 (substt x TX) (substt x T2)) as RHS.
      assert (GH = GU). admit. subst GU. 
      eapply IHnl. eauto. simpl. eauto. simpl. omega. omega. eauto.
      destruct RHS as [nr RHS].
      (* transitivity *)
      assert (vtpdd m G1 x (substt x T2)) as BB.
      unfold substt. simpl. eapply H3. (* trans *) eapply H. eapply RHS.
      (* to stp *)
      eu. eexists. eapply stp2_var1. eauto. 

    + SCase "miss". (* right now cannot happen. sketching case to see if it will work *)
      assert (nat_compare x0 0 = Gt) as E1. admit. 
      unfold substt. simpl. rewrite E1.
      assert (index x0 (GH ++ [TX]) = index (x0-1) (map (substt x) GH)) as IL. admit.
      assert (stpd2 m2 false [TX0] G1 TX0 (subst 0 (TVar true x) T2)).
      admit.
      eu. eexists. eapply stp2_vara1. simpl. unfold substt in IL. rewrite <-IL. eauto.
      rewrite app_nil_l. admit. admit. eapply H15.

  - Case "varab1". (* bind elim *)
    case_eq (beq_nat x0 0); intros E.
    + SCase "hit".
      eapply beq_nat_true_iff in E. subst x0.
      assert (stpd2 m2 true (map (substt x) GH)
                    G1 (substt x (TVar false 0)) (substt x (TBind T0))) as A.
      eapply IHnl. eauto. eauto. eauto. omega. eauto.
      unfold substt at 3 in A. unfold substt at 2 in A. simpl in A.
      eu. inversion A. (* need induction if we have varb1 and varb2 ? *)
      * subst. inversion H14. subst. 
      assert ((subst 0 (TVar true x) T0) = T0) as R. admit. (* closed! *)
      rewrite R in H9.
      eexists. eapply stp2_var1. unfold substt. simpl. rewrite subst_open_commute. eapply H9.
    + SCase "miss". admit. (* not now! *)

  - Case "varab2". (* bind intro *)
    case_eq (beq_nat x0 0); intros E.
    + SCase "hit".
      eapply beq_nat_true_iff in E. subst x0.
      assert (stpd2 m2 true (map (substt x) GH)
                    G1 (substt x (TVar false 0)) (substt x (open 0 (TVar false 0) T0))) as A.
      eapply IHnl. eauto. eauto. eauto. omega. eauto.
      admit.
      (* add one vtp_bind to LHS *)
      
    + SCase "miss". admit. 
      
  - Case "ssel1".
    assert (substt x TX0 = TX0) as R. admit. (* closed *)
    assert (stpd2 m2 false (map (substt x) GH) G1 TX0 (substt x T2)).
    rewrite <-R. eapply IHnl. eauto. eauto. eauto. omega. eauto.
    eu. eexists. eapply stp2_strong_sel1. eauto. eauto. 
    
  - Case "ssel2". admit.

  - Case "sel1". subst.
    assert (stpd2 m2 true (map (substt x) GH) G1 (substt x ((TVar b0 x0))) (TMem TBot (substt x T2))). admit. 
    eu. eexists. destruct b0.
    simpl. eapply stp2_sel1. unfold substt in H5 at 2. simpl in H5. eapply H5.
    simpl. unfold substt at 2. unfold substt at 2 in H5. simpl in H5. simpl. destruct (nat_compare x0 0); eapply stp2_sel1; unfold substt in H5 at 2; simpl in H5; eapply H5. 

  - Case "bindx". admit.

  - Case "wrapf". admit.
  - Case "transf". admit.
    
    Grab Existential Variables.
    apply 0.
Qed.

*)



Lemma stp2_trans: forall l, forall n, forall k, forall m1 m2 b G1 x T2 T3 n1 n2,
  vtp m1 G1 x T2 n1 -> 
  stp2 m2 b [] G1 T2 T3 n2 ->
  m1 < l -> n2 < n -> n1 < k -> 
  vtpdd m1 G1 x T3.
Proof.
  intros l. induction l. intros. solve by inversion.
  intros n. induction n. intros. solve by inversion.
  intros k. induction k; intros. solve by inversion.
  destruct b.
  (* b = true *) {
  inversion H.
  - Case "top". inversion H0; subst; invty.
    + SCase "top". repeat eexists; eauto.
    + SCase "ssel2".
      assert (vtpdd m1 G1 x TX). eapply IHn; eauto. omega. 
      eu. repeat eexists. eapply vtp_sel. eauto. eauto. eauto.
    + SCase "sel2".
      destruct b. 
      * inversion H10. subst. inversion H7. subst. 
        assert (vtpdd m1 G1 x TX). eapply IHn; eauto. omega. 
        eu. repeat eexists. eapply vtp_sel. eauto. eauto. eauto.
      * assert (closed (length ([]:tenv)) (length G1) 0 (TVar false x1)).
        eapply stpd2_closed1. eauto.
        simpl in H5. inversion H5. omega.
      
  - Case "bool". inversion H0; subst; invty.
    + SCase "top". repeat eexists. eapply vtp_top. eapply index_max. eauto. eauto. 
    + SCase "bool". repeat eexists; eauto. 
    + SCase "ssel2". 
      assert (vtpdd m1 G1 x TX). eapply IHn; eauto. omega. 
      eu. repeat eexists. eapply vtp_sel. eauto. eauto. eauto.
    + SCase "sel2". admit. (* see above *)
  - Case "mem". inversion H0; subst; invty.
    + SCase "top". repeat eexists. eapply vtp_top. eapply index_max. eauto. eauto. 
    + SCase "mem". invty. subst.
      repeat eexists. eapply vtp_mem. eauto.
      eapply stp2_transf. eauto. eapply H5.
      eapply stp2_transf. eauto. eapply H13.
      eauto. 
    + SCase "sel2". 
      assert (vtpdd m1 G1 x TX0). eapply IHn; eauto. omega. 
      eu. repeat eexists. eapply vtp_sel. eauto. eauto. eauto. 
    + SCase "sel2". admit. (* see above *)
  - Case "bind". 
    inversion H0; subst; invty.
    + SCase "top". repeat eexists. eapply vtp_top. admit. (* x < length G1 *) eauto. 
    + SCase "sel2". 
      assert (vtpdd (S m) G1 x TX). eapply IHn; eauto. omega. 
      eu. repeat eexists. eapply vtp_sel. eauto. eauto. eauto. 
    + SCase "sel2". admit. (* see above *)
    + SCase "bindx".
      invty. subst.
      remember (TVar false (length [])) as VZ.
      remember (TVar true x) as VX.

      (* left *)
      assert (vtpd m G1 x (open 0 VX T0)) as LHS. eexists. eassumption.
      eu.
      (* right *)
      assert (stpd2 m0 false (open 0 VZ T0 :: []) G1 (open 0 VZ T0) (open 0 VZ T4)) as RHS1.
      eexists. eassumption.
      eu.
      
      (* narrow and subst! *)

      assert (stpd2 m0 false (map (substt x) []) G1 (substt x (open 0 VZ T0)) (substt x (open 0 VZ T4))) as RHS12. {
        eapply stp2_subst_narrow0. rewrite app_nil_l. eauto. eauto.
        {
          intros. eapply stp2_subst_narrowX. unfold substt. instantiate (2:=(open 0 VZ T0)). subst. rewrite subst_open_commute. eapply LHS. eauto. eauto. eauto.
          {
            intros. eapply IHl. eauto. eauto. omega. eauto. eauto. 
          }
        }
      }
      assert (stpd2 m0 false [] G1 (open 0 VX T0) (open 0 VX T4)) as RHS2. {
        subst VX VZ. unfold substt in RHS12.
        rewrite subst_open_commute in RHS12.
        rewrite subst_open_commute in RHS12.
        simpl in RHS12. simpl in RHS12.
        eapply RHS12. 
      }
      
      (* now trans *)
      assert (vtpdd m G1 x (open 0 VX T4)) as BB. {
        eu. subst. eapply IHl. eapply LHS. eapply RHS2. omega. eauto. eauto.
      }
      
      eu. eu. eu. repeat eexists. eapply vtp_bind. subst VX. eapply BB. omega. 

  - Case "ssel2". subst. inversion H0; subst; invty.
    + SCase "top". repeat eexists. eapply vtp_top. admit. (* x < length G1 *) eauto.
    + SCase "ssel1". index_subst. eapply IHn. eauto. eauto. eauto. omega. eauto.
    + SCase "ssel2". 
      assert (vtpdd m1 G1 x TX0). eapply IHn; eauto. omega. 
      eu. repeat eexists. eapply vtp_sel. eauto. eauto. eauto.
    + SCase "sel1".
      inversion H11.
      * inversion H8. index_subst. 
        eapply IHn. eauto. eauto. eauto. omega. eauto.

      (** subst. revert T2 H8 H12. induction n2. intros. inversion H12.
        intros. inversion H12. subst. inversion H14. subst. destruct T2; inversion H8. *)

    + SCase "sel2". admit. (* see above *)
      
  }  (* b = false *) {
    inversion H0.

  - Case "wrapf". eapply IHn. eapply H. eauto. eauto. omega. eauto.
  - Case "transf". subst.
    assert (vtpdd m1 G1 x T0) as LHS. eapply IHn. eauto. eauto. eauto. omega. eauto.
    eu.
    assert (vtpdd x0 G1 x T3) as BB. eapply IHn. eapply LHS. eauto. omega. omega. eauto. 
    eu. repeat eexists. eauto. omega. 
  }

Grab Existential Variables.
apply 0. apply 0. apply 0. apply 0. apply 0. 
Qed.

Lemma stp2_trans2: forall n, forall m b G1 T2 T3 x n1 n2,
  vtp2 G1 x T2 n1 ->
  stp2 m b [] G1 T2 T3 n2 -> n2 < n ->
  vtpd2 G1 x T3.
Proof.
  intros n. induction n. intros. omega.
  intros.
  inversion H.
  - Case "self". subst.
    inversion H0.
    + SCase "top". subst.
      eexists. eapply vtp2_down. eapply vtp_top. eauto.
    + SCase "varx". subst.
      eexists. eapply vtp2_refl. eauto.
    + SCase "var1". subst.
      eexists. eapply vtp2_down. eauto.
    + SCase "ssel2". subst.
      assert (vtpd2 G1 x TX). eapply IHn; eauto. omega. 
      eu. eexists. eapply vtp2_sel. eauto. eauto. 
    + SCase "sel2". subst.
      destruct b0.
      * inversion H3. inversion H6. subst. 
        assert (vtpd2 G1 x TX). eapply IHn; eauto. omega. 
        eu. eexists. eapply vtp2_sel. eauto. eauto.
      * assert (closed (length ([]:tenv)) (length G1) 0 (TVar false x0)) as CL.
        eapply stpd2_closed1. eauto.
        simpl in CL. inversion CL. omega.
    + SCase "wrapf". subst.
      clear H0. eapply IHn; eauto. omega.
    + SCase "transf". subst.
      assert (vtpd2 G1 x T2). eapply IHn; eauto. omega.
      eu. eapply IHn; eauto. omega. 
  - Case "down". subst.
    assert (vtpdd m0 G1 x T3). eapply stp2_trans; eauto.
    eu. eexists. eapply vtp2_down. eauto.
  - Case "sel". subst.
    inversion H0.
    + SCase "top". subst.
      eexists. eapply vtp2_down. eapply vtp_top. admit. (* wf/closed *)
    + SCase "varx". subst.
      index_subst.
      eapply IHn. eauto. eauto. omega. 
    + SCase "ssel1". subst.
      assert (vtpd2 G1 x TX0). eapply IHn. eapply H. eauto. omega.
      eu. eexists. eapply vtp2_sel. eauto. eauto. 
    + SCase "ssel2". subst.
      inversion H12. subst. inversion H6. subst. 
      index_subst.
      eapply IHn. eapply H3. eauto. omega.
    + SCase "sel1". subst.
      destruct b0.
      * inversion H4. inversion H7. subst. 
        assert (vtpd2 G1 x TX0). eapply IHn. eapply H. eauto. omega.
        eu. eexists. eapply vtp2_sel. eauto. eauto.
      * assert (closed (length ([]:tenv)) (length G1) 0 (TVar false x0)) as CL.
        eapply stpd2_closed1. eauto.
        simpl in CL. inversion CL. omega.
    + SCase "wrapf". subst.
      clear H0. eapply IHn; eauto. omega. 
    + SCase "transf". subst.
      assert (vtpd2 G1 x T2). eapply IHn; eauto. omega.
      eu. eapply IHn; eauto. omega. 

Grab Existential Variables.
apply 0. apply 0. apply 0. apply 0. apply 0. 
Qed.



(* TODO: stp_to_stp2 *)

(* TODO: specific inversion lemmas *)

(* TODO: evaluation semantics / soundness *)


End STLC.