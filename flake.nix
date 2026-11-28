{
  description = "math-coding v5 — source-linked evidence and re-evaluation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e94cb152ed51bd6e24eb4a41f1460252beb52cd2";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;
        minimalOcamlDeps = packageSet: with packageSet; [ yojson digestif eqaf omd xmlm uutf uchar ];
        ocamlDeps = (with ocamlPackages; [ ocaml dune_3 ]) ++ minimalOcamlDeps ocamlPackages;
        # The node of the development shell comes from a package the binary
        # cache can provide. The full `nodejs` forbids substitutes, so a fresh
        # machine compiles it from the sources for twenty minutes. The slim
        # package carries the same node and the same npm, only the build of
        # the rest of the distribution is left out.
        nodePackages = [
          pkgs.nodejs-slim_22
          (pkgs.lib.getOutput "npm" pkgs.nodejs-slim_22)
          (pkgs.lib.getOutput "corepack" pkgs.nodejs-slim_22)
        ];
        staticOcamlPackages = pkgs.pkgsStatic.ocamlPackages.overrideScope (_: super: {
          yojson = super.yojson.overrideAttrs (_: { doCheck = false; });
          digestif = super.digestif.overrideAttrs (_: { doCheck = false; });
          omd = super.omd.overrideAttrs (_: { doCheck = false; });
          xmlm = super.xmlm.overrideAttrs (_: { doCheck = false; });
        });
        # The packages of the two JavaScript projects are fetched once, by a
        # derivation with a fixed output, and are taken from the store
        # afterwards. The checks of the console run in copies of the tree,
        # and every copy would otherwise download the same packages again:
        # the battery of the project spent minutes on downloads it had
        # already paid for.
        #
        # The output of the derivation is pinned by its hash. A changed
        # package-lock needs a new hash, and the build names it: run
        # `nix build .#console-deps` and put the hash it reports into
        # `outputHash` below.
        #
        # The derivation is not a part of the development shell: the sandbox
        # of a machine does not always have a network, and a shell that
        # waits for a download would not open there. The build that needs
        # the packages asks for the path of the store and finds the packages
        # there; a machine that does not have them installs them as before.
        consoleDeps = pkgs.runCommand "math-coding-console-deps" {
          nativeBuildInputs = nodePackages;
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-Mes+CRFuh6EVeBQREDNaxcVkq4WqhFbnWLyw4hvRZPI=";
        } ''
          cp -r ${./plugin/math-coding-console} plugin
          cp -r ${./console} page
          chmod -R u+w plugin page
          rm -rf plugin/node_modules page/node_modules
          (cd plugin && npm ci --ignore-scripts --no-audit --no-fund)
          (cd page && npm ci --ignore-scripts --no-audit --no-fund)
          mkdir -p $out/plugin $out/page
          mv plugin/node_modules $out/plugin/node_modules
          mv page/node_modules $out/page/node_modules
        '';
        siteLibs = packageSet: pkg: "${pkg}/lib/ocaml/${packageSet.ocaml.version}/site-lib";
        ocamlPath = pkgs.lib.concatMapStringsSep ":" (siteLibs ocamlPackages) ocamlDeps;
        mkBinary = { name, target }:
          pkgs.stdenv.mkDerivation {
            inherit name;
            src = ./.;
            nativeBuildInputs = [ ocamlPackages.ocaml ocamlPackages.dune_3 ] ++ ocamlDeps;
            buildInputs = minimalOcamlDeps ocamlPackages;
            OCAMLPATH = ocamlPath;
            buildPhase = ''
              runHook preBuild
              dune build --root . ${target}
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp _build/default/${target} $out/bin/${name}
              runHook postInstall
            '';
          };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "math-coding-5-dev";
          packages = ocamlDeps ++ (with pkgs; [ bash git coreutils findutils gnused ]) ++ nodePackages;
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            export OCAMLPATH="${ocamlPath}"
            # The notice goes to stderr: `nix develop -c mathc map --json` must
            # produce nothing but the map on stdout, and the banner is the
            # shell's chatter, not the method's answer.
            echo "math-coding 5 dev shell" >&2
            echo "  dune:   $(which dune)" >&2
            echo "  ocaml:  $(ocaml --version)" >&2
            echo "" >&2
            echo "  build:  dune build --root ." >&2
            echo "  test:   dune runtest --root . --force" >&2
            echo "  method: dune exec --root . ./bin/mathc.exe -- map" >&2
            # The development shell stays in the store. `nix develop` roots it
            # only while the shell is open, and without a root of its own the
            # collector of garbage takes the whole toolchain away. The script
            # writes the root in the cache of the user, so no administrator is
            # needed for it.
            sh "${self}/scripts/keep-dev-shell.sh" \
              || echo "math-coding: the dev shell was not kept in the store" >&2
          '';
        };

        packages.default = mkBinary { name = "mathc"; target = "bin/mathc.exe"; };
        packages.console-deps = consoleDeps;
        packages.stand = pkgs.symlinkJoin {
          name = "mathc-with-stand";
          paths = [
            (mkBinary { name = "mathc"; target = "bin/mathc.exe"; })
            (mkBinary { name = "stand"; target = "bin/stand.exe"; })
          ];
        };

        packages.portable = pkgs.pkgsStatic.stdenv.mkDerivation {
          name = "mathc-portable";
          src = ./.;
          nativeBuildInputs = [ staticOcamlPackages.ocaml staticOcamlPackages.dune_3 ]
            ++ minimalOcamlDeps staticOcamlPackages;
          buildInputs = minimalOcamlDeps staticOcamlPackages;
          OCAMLPATH = pkgs.lib.concatMapStringsSep ":" (siteLibs staticOcamlPackages)
            (minimalOcamlDeps staticOcamlPackages);
          NIX_LDFLAGS = "-static";
          dontPatchElf = true;
          # The static runtime of OCaml 5 reserves the stack for its signal
          # handlers, and the sandbox of the builder offers less than it
          # needs: the compiler dies with "Failed to allocate signal stack"
          # before it reads a file. The limit of the shell that starts the
          # build does not reach the builder, so the bigger stack is asked
          # for here, where the compiler actually runs.
          shellHook = ''
            ulimit -s 65536 || true
          '';
          buildPhase = ''
            runHook preBuild
            dune build --root . bin/mathc.exe bin/stand.exe
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp _build/default/bin/mathc.exe $out/bin/mathc
            cp _build/default/bin/stand.exe $out/bin/stand
            runHook postInstall
          '';
        };
      });
}
