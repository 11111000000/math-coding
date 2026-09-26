{
  description = "math-coding 3.0-alpha — risk-adaptive assurance protocol";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            ocamlPackages.alcotest
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
          ] ++ ocamlSelect ocamlPackages;
          buildInputs = [ pkgs.git ];
          buildPhase = ''
            runHook preBuild
            dune build --root . bin/mathc.exe
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp _build/default/bin/mathc.exe $out/bin/mathc
            runHook postInstall
          '';
        };

        checks.default = pkgs.stdenv.mkDerivation {
          name = "math-coding-tests";
          src = ./.;
          nativeBuildInputs = [
            ocamlPackages.ocaml
            ocamlPackages.alcotest
          ] ++ ocamlSelect ocamlPackages;
          buildPhase = ''
            runHook preBuild
            dune build --root . @tests/runtest
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            touch $out/ok
            runHook postInstall
          '';
        };
      });
}
