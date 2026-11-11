open Helpers

let executable root path body =
  write root path ("#!/bin/sh\n" ^ body);
  Unix.chmod (Filename.concat root path) 0o755

let () =
  let work = Io.temp_dir "mathc-installer-test" in
  Fun.protect ~finally:(fun () -> Io.remove_tree work) (fun () ->
      let project = in_repo "" in
      let package = Filename.concat work "package" in
      Unix.putenv "MATHC_PACKAGE" package;
      executable work "package/bin/mathc"
        "if [ \"${1:-}\" = \"--version\" ]; then printf 'mathc 5\\nbuild test\\n'; else exit 0; fi\n";
      executable work "package/bin/stand"
        "if [ \"${1:-}\" = \"--help\" ] || [ \"${1:-}\" = \"-h\" ]; then exit 0; else exit 2; fi\n";
      let bin_dir = Filename.concat work "bin" in
      let skill_dir = Filename.concat work "skills/math-coding" in
      let install options =
        Process.run ~timeout:30.0 ~root:project
          (Printf.sprintf "MATHC_INSTALL_DIR=%s MATHC_SKILL_DIR=%s sh install.sh%s"
             (Filename.quote bin_dir) (Filename.quote skill_dir) options)
      in
      let first = install "" in
      check (Printf.sprintf "installer failed: %s%s" first.stdout first.stderr) (first.code = 0);
      let installed = Filename.concat bin_dir "mathc" in
      check "mathc-stand is installed" (Sys.file_exists (Filename.concat bin_dir "mathc-stand"));
      check "build id is installed" (Sys.file_exists (Filename.concat bin_dir "mathc.build-id"));
      check "skill is installed" (contains (Io.read_file (Filename.concat skill_dir "SKILL.md")) "review-source");
      check "skill setup reference is installed"
        (Sys.file_exists (Filename.concat skill_dir "references/PROJECT-SETUP.md"));
      let installed_methodology = Filename.concat skill_dir "references/METHODOLOGY.md" in
      check "canonical methodology is installed" (Sys.file_exists installed_methodology);
      if Sys.file_exists installed_methodology then
        check "canonical methodology is installed verbatim"
          (Io.read_file installed_methodology
           = Io.read_file (Filename.concat project "skills/math-coding/references/METHODOLOGY.md"));
      let version = Process.run ~root:work (Filename.quote installed ^ " --version") in
      check "installed binary runs" (version.code = 0 && contains version.stdout "mathc 5");
      check "installation is idempotent" ((install "").code = 0);
      executable work "bin/mathc" "exit 0\n";
      let foreign = Io.read_file installed in
      let refused = install "" in
      check "an unrelated binary is not overwritten"
        (refused.code = 2 && contains refused.stderr "refusing to overwrite" && Io.read_file installed = foreign);
      let forced = install " --force" in
      check "an explicit upgrade succeeds" (forced.code = 0);
      let backup_prefix = "mathc.backup" in
      let backups = Sys.readdir bin_dir |> Array.to_list |> List.filter (fun name ->
        String.length name >= String.length backup_prefix
        && String.sub name 0 (String.length backup_prefix) = backup_prefix) in
      check "the replaced binary is backed up" (backups <> []);
      check "the backup preserves the previous binary"
        (List.exists (fun name -> Io.read_file (Filename.concat bin_dir name) = foreign) backups);
      check "the upgrade restores the expected binary"
        ((Process.run ~root:work (Filename.quote installed ^ " --version")).code = 0);
      executable work "package/bin/mathc" "exit 2\n";
      let previous = Io.read_file installed in
      let failed = install " --force" in
      check "a failed upgrade preserves the previous binary"
        (failed.code <> 0 && Io.read_file installed = previous);
      print_endline "agent-installer: PASS")
