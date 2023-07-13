{
  description = "A fast static site generator in a single binary with everything built-in.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-analyzer" ];
        };
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # TODO: Better filter
        filter = path: type:
          (pkgs.lib.cleanSourceFilter path type) || (craneLib.filterCargoSources path type);
        src = pkgs.lib.cleanSourceWith {
          src = craneLib.path ./.;
          inherit filter;
        };

        commonArgs = { inherit src; };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        zola = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });
     in
      {
        packages.default = zola;
        apps.default = flake-utils.lib.mkApp { drv = zola; };

        devShells.default = pkgs.mkShell {
          packages = [ rustToolchain pkgs.cargo-insta ];
        };
      }
    );
}
