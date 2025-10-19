{
  lib,
  linuxKernel,
  recurseIntoAttrs,
}:
let
  patchKernel =
    { original, patches }:
    original.override (originalArgs: {
      kernelPatches =
        (originalArgs.kernelPatches or [ ])
        ++ map (patch: {
          name = builtins.baseNameOf patch;
          inherit patch;
        }) patches;
    });
in
rec {
  kernels = recurseIntoAttrs {
    linux_6_16_tso = patchKernel {
      original = linuxKernel.kernels.linux_6_16;
      patches = import ./linux_6_16_tso/patches.nix;
    };
  };
  packages = recurseIntoAttrs (lib.mapAttrs (k: linuxKernel.packagesFor) kernels);
}
