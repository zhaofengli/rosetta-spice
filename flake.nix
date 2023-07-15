{
  description = "RosettaLinux augmentation tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }: let
    # System types to support.
    supportedSystems = [ "aarch64-linux" ];
  in flake-utils.lib.eachSystem supportedSystems (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    inherit (pkgs) lib;

    patchRosetta = pkgs.callPackage ./patch-rosetta.nix {
      rosetta-spice = self.packages.${system}.rosetta-spice;
    };
  in {
    packages = rec {
      rosetta-spice = pkgs.rustPlatform.buildRustPackage {
        name = "rosetta-spice";
        src = lib.cleanSourceWith {
          filter = name: type: !(lib.hasSuffix ".nix" name);
          src = ./.;
        };
        cargoLock.lockFile = ./Cargo.lock;
      };
      rosetta-orig = pkgs.callPackage ./rosetta.nix { };
      rosetta = patchRosetta rosetta-orig;
    };

    devShell = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        rustc cargo rustfmt clippy
        pkg-config
        elfutils
        gdb
        bbe
      ];
    };
  });
}
