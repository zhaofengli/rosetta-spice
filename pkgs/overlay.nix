self: super:
let
  inherit (self) callPackage recurseIntoAttrs;
in {
  rosetta-spice-extras = recurseIntoAttrs rec {
    linuxKernel = recurseIntoAttrs (callPackage ./linux-kernels { });
  };
}
