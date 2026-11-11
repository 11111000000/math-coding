let with_copy root f =
  Io.with_temp_dir (fun directory ->
      let checkout = Filename.concat directory "checkout" in
      Unix.mkdir checkout 0o700;
      (match Git.head_commit root with
       | Some _ ->
           ignore (Process.run ~timeout:60.0 ~root
             (Printf.sprintf "git clone --no-hardlinks --no-checkout %s %s"
                (Filename.quote root) (Filename.quote checkout)));
           ignore (Process.run ~timeout:30.0 ~root:checkout "git checkout --detach HEAD")
       | None ->
           ignore (Process.run ~timeout:10.0 ~root:checkout "git init -q"));
      (match Git.repository_files root with
       | Error error -> failwith error
       | Ok files ->
           (match Git.repository_files checkout with
            | Error error -> failwith error
            | Ok previous_files ->
                List.iter
                  (fun file ->
                    if not (List.mem file files) then Sys.remove (Filename.concat checkout file))
                  previous_files);
           List.iter
             (fun file ->
               let destination = Filename.concat checkout file in
               Io.mkdir_p (Filename.dirname destination);
               Io.copy_file (Filename.concat root file) destination)
             files;
           let staged = Process.run ~timeout:30.0 ~root:checkout "git add -A -- ." in
           if staged.code <> 0 then failwith ("cannot snapshot the control tree: " ^ staged.stderr));
      f checkout)
