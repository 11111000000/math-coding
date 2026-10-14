(* tests/policy_test.ml - hierarchical policy composition tests.
 *
 * Each test asserts one obligation from
 * decisions/multi-policy-hierarchy-2026-10.yaml:
 *
 *   resolve_policy_no_parent_returns_same
 *   resolve_policy_one_level_inherits_parent
 *   resolve_policy_three_level_chain_returns_cumulative
 *   resolve_policy_cycle_returns_MC_POLICY_CYCLE
 *   resolve_policy_mode_floor_takes_max
 *
 * The tests are pure: each calls `Policy.resolve_policy` with a
 * constructed policy list and asserts the produced
 * obligations/scope_paths/mode_floor match the expected contract.
 * They never touch the filesystem and do not require dune cram. *)

(* Sample policies used across the suite. The fixtures are
   declared top-down so each test can compose its own chain. *)

let[@warning "-32"] root =
  {
    Policy.policy_id = "root";
    Policy.parent = None;
    scope_paths = [ "lib/**" ];
    obligations =
      [
        {
          Policy.obligation_kind = "lint";
          Policy.path_namespace = "lib";
        };
      ];
    mode_floor = `Standard;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] middle =
  {
    Policy.policy_id = "middle";
    Policy.parent = Some "root";
    scope_paths = [ "lib/payments/**" ];
    obligations =
      [
        {
          Policy.obligation_kind = "lint";
          Policy.path_namespace = "lib";
        };
        {
          Policy.obligation_kind = "pci-audit";
          Policy.path_namespace = "payments";
        };
      ];
    mode_floor = `Strict;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] leaf =
  {
    Policy.policy_id = "leaf";
    Policy.parent = Some "middle";
    scope_paths = [ "lib/payments/exact/**" ];
    obligations =
      [
        {
          Policy.obligation_kind = "lint";
          Policy.path_namespace = "lib";
        };
        {
          Policy.obligation_kind = "pci-audit";
          Policy.path_namespace = "payments";
        };
        {
          Policy.obligation_kind = "exhaustive-attestation";
          Policy.path_namespace = "payments";
        };
      ];
    mode_floor = `Exhaustive;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

(* Cycle: a -> b -> a. *)
let[@warning "-32"] cyc_a =
  {
    Policy.policy_id = "cyc-a";
    Policy.parent = Some "cyc-b";
    scope_paths = [ "x/**" ];
    obligations = [];
    mode_floor = `Standard;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] cyc_b =
  {
    Policy.policy_id = "cyc-b";
    Policy.parent = Some "cyc-a";
    scope_paths = [ "y/**" ];
    obligations = [];
    mode_floor = `Standard;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

(* Strict parent, Exhaustive child — confirms mode_floor max. *)
let[@warning "-32"] strict_parent =
  {
    Policy.policy_id = "strict-parent";
    Policy.parent = None;
    scope_paths = [ "a/**" ];
    obligations = [];
    mode_floor = `Strict;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] exhaustive_child =
  {
    Policy.policy_id = "exhaustive-child";
    Policy.parent = Some "strict-parent";
    scope_paths = [ "a/deep/**" ];
    obligations = [];
    mode_floor = `Exhaustive;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

(* --- resolve_policy_no_parent_returns_same --- *)

let[@warning "-32"] resolve_policy_no_parent_returns_same () =
  let result = Policy.resolve_policy [ root ] "root" in
  match result with
  | Error d ->
      Alcotest.failf "expected Ok, got Error %s" d.Diagnostic.message
  | Ok resolved ->
      Alcotest.(check string)
        "resolved.policy_id" "root" resolved.policy_id;
      Alcotest.(check (option string))
        "resolved.parent = None" None resolved.parent;
      Alcotest.(check (list string))
        "scope_paths carried over"
        [ "lib/**" ]
        resolved.scope_paths;
      Alcotest.(check int)
        "obligations carried over" 1
        (List.length resolved.obligations);
      let mode_str =
        match resolved.mode_floor with
        | `Tiny -> "Tiny"
        | `Light -> "Light"
        | `Standard | `Considered -> "Standard"
        | `Strict -> "Strict"
        | `Exhaustive -> "Exhaustive"
      in
      Alcotest.(check string) "mode_floor carried over" "Standard" mode_str

(* --- resolve_policy_one_level_inherits_parent --- *)

let[@warning "-32"] resolve_policy_one_level_inherits_parent () =
  let result = Policy.resolve_policy [ root; middle ] "middle" in
  match result with
  | Error d ->
      Alcotest.failf "expected Ok, got Error %s" d.Diagnostic.message
  | Ok resolved ->
      Alcotest.(check string)
        "resolved.policy_id is the child's id" "middle" resolved.policy_id;
      Alcotest.(check (option string))
        "resolved.parent is None (chain flattened)" None resolved.parent;
      (* scope_paths = parent ∪ child *)
      Alcotest.(check (list string))
        "scope_paths = parent ∪ child"
        [ "lib/**"; "lib/payments/**" ]
        resolved.scope_paths;
      (* obligations deduplicated, count = 2 distinct refs *)
      Alcotest.(check int)
        "obligations deduplicated to 2 entries" 2
        (List.length resolved.obligations);
      let mode_str =
        match resolved.mode_floor with
        | `Strict -> "Strict"
        | _ -> "NotStrict"
      in
      Alcotest.(check string)
        "mode_floor = max(Standard, Strict) = Strict" "Strict" mode_str

(* --- resolve_policy_three_level_chain_returns_cumulative --- *)

let[@warning "-32"] resolve_policy_three_level_chain_returns_cumulative () =
  let result =
    Policy.resolve_policy [ root; middle; leaf ] "leaf"
  in
  match result with
  | Error d ->
      Alcotest.failf "expected Ok, got Error %s" d.Diagnostic.message
  | Ok resolved ->
      Alcotest.(check string)
        "resolved.policy_id is the leaf's id" "leaf" resolved.policy_id;
      Alcotest.(check (list string))
        "scope_paths = root ∪ middle ∪ leaf"
        [ "lib/**"; "lib/payments/**"; "lib/payments/exact/**" ]
        resolved.scope_paths;
      Alcotest.(check int)
        "cumulative distinct obligation refs (3)" 3
        (List.length resolved.obligations);
      let mode_str =
        match resolved.mode_floor with
        | `Exhaustive -> "Exhaustive"
        | _ -> "NotExhaustive"
      in
      Alcotest.(check string)
        "mode_floor = max(Standard, Strict, Exhaustive) = Exhaustive"
        "Exhaustive" mode_str

(* --- resolve_policy_cycle_returns_MC_POLICY_CYCLE --- *)

let[@warning "-32"] resolve_policy_cycle_returns_MC_POLICY_CYCLE () =
  let result = Policy.resolve_policy [ cyc_a; cyc_b ] "cyc-a" in
  match result with
  | Ok _ -> Alcotest.fail "expected Error, got Ok for a policy cycle"
  | Error diag ->
      Alcotest.(check string)
        "diag.code = MC-POLICY-CYCLE" "MC-POLICY-CYCLE" diag.Diagnostic.code

(* --- resolve_policy_mode_floor_takes_max --- *)

let[@warning "-32"] resolve_policy_mode_floor_takes_max () =
  let result =
    Policy.resolve_policy [ strict_parent; exhaustive_child ]
      "exhaustive-child"
  in
  match result with
  | Error d ->
      Alcotest.failf "expected Ok, got Error %s" d.Diagnostic.message
  | Ok resolved -> (
      match resolved.mode_floor with
      | `Exhaustive -> ()
      | _ -> Alcotest.fail "mode_floor should be max(Strict, Exhaustive)")

(* --- resolve_policy_signature_introspectable (uses the type
       documented in the obligation) --- *)

let[@warning "-32"] resolve_policy_signature_introspectable () =
  (* Smoke: build a value at the right type, destructure it. *)
  let result : (Policy.policy, Diagnostic.t) result =
    Policy.resolve_policy [ root ] "root"
  in
  match result with Ok _ -> () | Error _ -> ()

let () =
  Alcotest.run "policy kernel (hierarchy)"
    [
      ( "resolve_policy_no_parent_returns_same",
        [
          Alcotest.test_case "parent=None resolves to itself" `Quick
            resolve_policy_no_parent_returns_same;
        ] );
      ( "resolve_policy_one_level_inherits_parent",
        [
          Alcotest.test_case "parent + child merged" `Quick
            resolve_policy_one_level_inherits_parent;
        ] );
      ( "resolve_policy_three_level_chain_returns_cumulative",
        [
          Alcotest.test_case "root -> middle -> leaf merged" `Quick
            resolve_policy_three_level_chain_returns_cumulative;
        ] );
      ( "resolve_policy_cycle_returns_MC_POLICY_CYCLE",
        [
          Alcotest.test_case "a -> b -> a detected as cycle" `Quick
            resolve_policy_cycle_returns_MC_POLICY_CYCLE;
        ] );
      ( "resolve_policy_mode_floor_takes_max",
        [
          Alcotest.test_case "max(Strict, Exhaustive) = Exhaustive" `Quick
            resolve_policy_mode_floor_takes_max;
        ] );
      ( "resolve_policy_signature_introspectable",
        [
          Alcotest.test_case "result type is (policy, Diagnostic.t) result"
            `Quick resolve_policy_signature_introspectable;
        ] );
    ]
