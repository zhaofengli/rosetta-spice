self: super:
let
  inherit (self) lib callPackage;
in {
  rosetta-spice-extras = lib.recurseIntoAttrs rec {
    linuxKernel = lib.recurseIntoAttrs (callPackage ./linux-kernels { });
  };
}
