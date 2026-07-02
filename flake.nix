{
  description = "math-coding — Nix flake for local Hugo dev server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = false;
          };
          # In nixpkgs 25.11, hugo is the extended build by default
          # (Hugo ≥ 0.110 ships extended as the only variant).
          hugo = pkgs.hugo;
          git = pkgs.git;
          bash = pkgs.bash;
      in
      {
        # Nix-managed dev environment: `nix develop`
        devShells.default = pkgs.mkShell {
          name = "math-coding-site";
          description = "Hugo dev environment for the math-coding site";

          packages = [
            hugo
            git
            bash
          ];

          shellHook = ''
            echo "math-coding site dev environment"
            echo "  hugo: $(hugo version)"
            echo "  repo: $(pwd)"
            echo ""
            echo "Commands:"
            echo "  site/sync-content.sh   # sync content from main repo"
            echo "  cd site && hugo server # start dev server on :1313"
            echo "  hugo --minify --gc     # production build"
            echo ""
          '';
        };

        # Convenience: build the site as a static derivation
        packages.default = pkgs.stdenv.mkDerivation {
          name = "math-coding-site";
          src = ./.;
          nativeBuildInputs = [ hugo git ];
          buildPhase = ''
            export HOME=$TMPDIR
            site/sync-content.sh
            cd site
            hugo --minify --gc
          '';
          installPhase = ''
            mkdir -p $out
            cp -r site/public/. $out/
          '';
        };
      });
}
