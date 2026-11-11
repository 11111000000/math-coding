open Domain

let pending root spec =
  match Trail.read root with
  | Error error -> Error error
  | Ok evidence ->
      let now = int_of_float (Unix.time ()) in
      Ok
        (List.filter_map
           (fun (claim : claim) ->
             let state = Verdict.state_of_claim ~now
               ?materials:(Git.digest_of_scope root ~scope:claim.scope) claim evidence in
             let changed =
               match claim.source with
               | None -> false
               | Some source -> Git.digest_of_repo_file root source.path <> Some source.digest
             in
             if changed || state <> Holds then Some claim.id else None)
           spec.claims)
