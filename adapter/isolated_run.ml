let with_copy root f =
  let ( let* ) result next = match result with Ok value -> next value | Error error -> Error error in
  try
    Io.with_temp_dir (fun directory ->
        let checkout = Filename.concat directory "checkout" in
        Unix.mkdir checkout 0o700;
        let* () =
          match Git.head_commit root with
          | Some _ ->
              let clone = Process.run ~timeout:60.0 ~root
                (Printf.sprintf "git clone --no-hardlinks --no-checkout %s %s"
                   (Filename.quote root) (Filename.quote checkout)) in
              if clone.code <> 0 then Error ("cannot clone the control tree: " ^ clone.stderr)
              else
                let checkout_result = Process.run ~timeout:30.0 ~root:checkout "git checkout --detach HEAD" in
                if checkout_result.code <> 0 then Error ("cannot check out the control tree: " ^ checkout_result.stderr)
                else Ok ()
          | None ->
              let initialized = Process.run ~timeout:10.0 ~root:checkout "git init -q" in
              if initialized.code <> 0 then Error ("cannot initialize the control tree: " ^ initialized.stderr)
              else Ok ()
        in
        let* files = Git.repository_files root in
        let* previous_files = Git.repository_files checkout in
        List.iter
          (fun file ->
            if not (List.mem file files) then Sys.remove (Filename.concat checkout file))
          previous_files;
        List.iter
          (fun file ->
            let destination = Filename.concat checkout file in
            Io.mkdir_p (Filename.dirname destination);
            Io.copy_file (Filename.concat root file) destination)
          files;
        let staged = Process.run ~timeout:30.0 ~root:checkout "git add -A -- ." in
        if staged.code <> 0 then Error ("cannot snapshot the control tree: " ^ staged.stderr)
        else Ok (f checkout))
  with exn -> Error (Printexc.to_string exn)
