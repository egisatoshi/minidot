(* Full safety for STLC *)
(* values well-typed with respect to runtime environment *)
(* inversion lemma structure *)
(* proper naming *)

Require Export SfLib.

Require Export Arith.EqNat.
Require Export Arith.Le.

Module STLC.

Definition id := nat.


Inductive ty : Type :=
  | TBool  : ty
  | TFun   : ty -> ty -> ty
.

  

Inductive tm : Type :=
  | ttrue : tm
  | tfalse : tm
  | tvar : id -> tm
  | tapp : tm -> tm -> tm (* f(x) *)
  | tabs : id -> id -> tm -> tm (* \f x.y *)
.


Inductive vl : Type :=
| vbool : bool -> vl
| vabs  : list (id*vl) -> id -> id -> tm -> vl
.

Definition env := list (id*vl).
Definition tenv := list (id*ty).

Hint Unfold env.
Hint Unfold tenv.

Fixpoint length {X: Type} (l : list X): nat :=
  match l with
    | [] => 0
    | _::l' => 1 + length l'
  end.

Fixpoint fresh {X: Type} (l : list (id * X)): nat :=
  match l with
    | [] => 0
    | (n',a)::l' => 1 + n'
  end.

Fixpoint index {X : Type} (n : id) (l : list (id * X)) : option X :=
  match l with
    | [] => None
    | (n',a) :: l'  =>
      if le_lt_dec (fresh l') n' then
        if (beq_nat n n') then Some a else index n l'
      else None
  end.


Inductive has_type : tenv -> tm -> ty -> Prop :=
| t_true: forall env,
           has_type env ttrue TBool
| t_false: forall env,
           has_type env tfalse TBool
| t_var: forall x env T1,
           index x env = Some T1 ->
           has_type env (tvar x) T1
| t_app: forall env f x T1 T2,
           has_type env f (TFun T1 T2) ->
           has_type env x T1 ->
           has_type env (tapp f x) T2
| t_abs: forall env f x y T1 T2,
           has_type ((x,T1)::(f,TFun T1 T2)::env) y T2 -> 
           has_type env (tabs f x y) (TFun T1 T2)
.

Inductive wf_env : env -> tenv -> Prop := 
| wfe_nil : wf_env nil nil
| wfe_cons : forall n v t vs ts,
    val_type ((n,v)::vs) v t ->
    wf_env vs ts ->
    wf_env (cons (n,v) vs) (cons (n,t) ts)                                    

with val_type : env -> vl -> ty -> Prop :=
| v_bool: forall venv b,
    val_type venv (vbool b) TBool
| v_abs: forall env venv tenv f x y T1 T2,
    wf_env env tenv ->
    has_type ((x,T1)::(f,TFun T1 T2)::tenv) y T2 ->
    val_type venv (vabs env f x y) (TFun T1 T2)
.


Inductive stp: env -> ty -> env -> ty -> Prop :=
| stp_refl: forall G1 G2 T,
   stp G1 T G2 T.




(*
None             means timeout
Some None        means stuck
Some (Some v))   means result v

Could use do-notation to clean up syntax.
 *)

Fixpoint teval(n: nat)(env: env)(t: tm){struct n}: option (option vl) :=
  match n with
    | 0 => None
    | S n =>
      match t with
        | ttrue      => Some (Some (vbool true))
        | tfalse     => Some (Some (vbool false))
        | tvar x     => Some (index x env)
        | tabs f x y => Some (Some (vabs env f x y))
        | tapp ef ex   =>
          match teval n env ex with
            | None => None
            | Some None => Some None
            | Some (Some vx) =>
              match teval n env ef with
                | None => None
                | Some None => Some None
                | Some (Some (vbool _)) => Some None
                | Some (Some (vabs env2 f x ey)) =>
                  teval n ((x,vx)::(f,vabs env2 f x ey)::env2) ey
              end
          end
      end
  end.


Hint Constructors ty.
Hint Constructors tm.
Hint Constructors vl.


Hint Constructors has_type.
Hint Constructors val_type.
Hint Constructors wf_env.
Hint Constructors stp.

Hint Constructors option.
Hint Constructors list.

Hint Unfold index.
Hint Unfold length.

Hint Resolve ex_intro.

Lemma wf_fresh : forall vs ts,
                    wf_env vs ts ->
                    (fresh vs = fresh ts).
Proof.
  intros. induction H. auto.
  compute. eauto.
Qed.

Hint Immediate wf_fresh.

Lemma index_max : forall X vs n (T: X),
                       index n vs = Some T ->
                       n < fresh vs.
Proof.
  intros X vs. induction vs.
  - Case "nil". intros. inversion H.
  - Case "cons".
    intros. inversion H. destruct a.
    case_eq (le_lt_dec (fresh vs) i); intros ? E1.
    + SCase "ok".
      rewrite E1 in H1.
      case_eq (beq_nat n i); intros E2.
      * SSCase "hit".
        eapply beq_nat_true in E2. subst n. compute. eauto.
      * SSCase "miss".
        rewrite E2 in H1.
        assert (n < fresh vs). eapply IHvs. apply H1.
        compute. omega.
    + SCase "bad".
      rewrite E1 in H1. inversion H1.
Qed.

Lemma valtp_extend : forall vs x v v1 T,
                       val_type vs v T ->
                       val_type ((x,v1)::vs) v T.
Proof. intros. induction H; eauto. Qed.

Lemma le_xx : forall a b,
                       a <= b ->
                       exists E, le_lt_dec a b = left E.
Proof. intros.
  case_eq (le_lt_dec a b). intros. eauto.
  intros. omega.     
Qed.

Lemma index_extend : forall X vs n n' x (T: X),
                       index n vs = Some T ->
                       fresh vs <= n' ->
                       index n ((n',x)::vs) = Some T.

Proof.
  intros.
  assert (n < fresh vs). eapply index_max. eauto.
  assert (n <> n'). omega.
  assert (beq_nat n n' = false) as E. eapply beq_nat_false_iff; eauto.
  assert (fresh vs <= n') as E2. omega.
  elim (le_xx (fresh vs) n' E2). intros ? EX.
  unfold index. unfold index in H. rewrite H. rewrite E. rewrite EX. reflexivity.
Qed.



Lemma index_safe_ex: forall H1 G1 TF i,
             wf_env H1 G1 ->
             index i G1 = Some TF ->
             exists v, index i H1 = Some v /\ val_type H1 v TF.
Proof. intros. induction H.
   - Case "nil". inversion H0.
   - Case "cons". inversion H0.
     case_eq (le_lt_dec (fresh ts) n); intros ? E1.
     + SCase "ok".
       rewrite E1 in H3.
       assert ((fresh ts) <= n) as QF. eauto. rewrite <-(wf_fresh vs ts H1) in QF.
       elim (le_xx (fresh vs) n QF). intros ? EX.

       case_eq (beq_nat i n); intros E2.
       * SSCase "hit".         
         assert (index i ((n, v) :: vs) = Some v). eauto. unfold index. rewrite EX. rewrite E2. eauto.
         assert (t = TF).
         unfold index in H0. rewrite E1 in H0. rewrite E2 in H0. inversion H0. eauto.
         subst t. eauto.
       * SSCase "miss".
         rewrite E2 in H3.
         assert (exists v0, index i vs = Some v0 /\ val_type vs v0 TF) as HI. eapply IHwf_env. eauto.
         inversion HI as [v0 HI1]. inversion HI1.
         eexists. econstructor. eapply index_extend; eauto. eapply valtp_extend; eauto.
     + SSCase "bad".
       rewrite E1 in H3. inversion H3.
Qed.

  
Inductive res_type: env -> option vl -> ty -> Prop :=
| not_stuck: forall v T venv,
      val_type venv v T ->
      res_type venv (Some v) T.

Hint Constructors res_type.
Hint Resolve not_stuck.


Lemma valtp_widen: forall vf H1 H2 T1 T2,
  val_type H1 vf T1 ->
  stp H1 T1 H2 T2 ->
  val_type H2 vf T2.
Proof.
  intros. inversion H; inversion H0; subst T2; subst; eauto.
Qed.


Lemma invert_abs: forall venv vf vx T1 T2,
  val_type venv vf (TFun T1 T2) ->
  exists env tenv f x y T3 T4,
    vf = (vabs env f x y) /\ 
    wf_env env tenv /\
    has_type ((x,T3)::(f,TFun T3 T4)::tenv) y T4 /\
    stp venv T1 ((x,vx)::(f,vf)::env) T3 /\
    stp ((x,vx)::(f,vf)::env) T4 venv T2.
Proof.
  intros. inversion H. repeat eexists; repeat eauto.
Qed.


(* if not a timeout, then result not stuck and well-typed *)

Theorem full_safety : forall n e tenv venv res T,
  teval n venv e = Some res -> has_type tenv e T -> wf_env venv tenv ->
  res_type venv res T.

Proof.
  intros n. induction n.
  (* 0 *)   intros. inversion H.
  (* S n *) intros. destruct e; inversion H; inversion H0.
  
  Case "True".  eapply not_stuck. eapply v_bool.
  Case "False". eapply not_stuck. eapply v_bool.

  Case "Var".
    destruct (index_safe_ex venv tenv0 T i) as [v [I V]]; eauto. 

    rewrite I. eapply not_stuck. eapply V.

  Case "App".
    remember (teval n venv e1) as tf.
    remember (teval n venv e2) as tx. 
    subst T.
    
    destruct tx as [rx|]; try solve by inversion.
    assert (res_type venv rx T1) as HRX. SCase "HRX". subst. eapply IHn; eauto.
    inversion HRX as [vx]. 

    destruct tf as [rf|]; subst rx; try solve by inversion.  
    assert (res_type venv rf (TFun T1 T2)) as HRF. SCase "HRF". subst. eapply IHn; eauto.
    inversion HRF as [vf].

    destruct (invert_abs venv vf vx T1 T2) as
        [env1 [tenv [f0 [x0 [y0 [T3 [T4 [EF [WF [HTY [STX STY]]]]]]]]]]]. eauto.
    (* now we know it's a closure, and we have has_type evidence *)

    assert (res_type ((x0,vx)::(f0,vf)::env1) res T4) as HRY.
      SCase "HRY".
        subst. eapply IHn. eauto. eauto.
        (* wf_env f x *) econstructor. eapply valtp_widen; eauto.
        (* wf_env f   *) econstructor. eapply v_abs; eauto.
        eauto.

    inversion HRY as [vy].

    eapply not_stuck. eapply valtp_widen; eauto.
    
  Case "Abs". intros. inversion H. inversion H0.
    eapply not_stuck. eapply v_abs; eauto.
Qed.

End STLC.