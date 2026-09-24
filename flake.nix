{
  description = "math-coding v2.0-Y — a discipline of recording decisions before code";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;
        ocamlSelect = p: [ p.dune_3 ];
      in
      {
        devShells.default = pkgs.mkShell {
          name = "math-coding-dev";
          packages = [
            ocamlPackages.ocaml
            pkgs.texliveSmall
            pkgs.pandoc
          ] ++ ocamlSelect ocamlPackages ++ (with pkgs; [
            git
            pkg-config
            gnumake
          ]);
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "mathc";
          src = ./.;
          nativeBuildInputs = [
            ocamlPackages.ocaml
            pkgs.texliveSmall
          ] ++ ocamlSelect ocamlPackages;
          buildInputs = [ pkgs.git ];
          buildPhase = ''
            runHook preBuild
            dune build --profile=release core/main.exe
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            install -Dm755 _build/default/core/main.exe $out/bin/mathc
            runHook postInstall
          '';
        };
      });
}