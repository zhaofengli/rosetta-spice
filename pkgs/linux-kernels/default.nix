{
  lib,
  linuxKernel,
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
  kernels = lib.recurseIntoAttrs {
    linux_6_16_tso = patchKernel {
      original = linuxKernel.kernels.linux_6_16;
      patches = import ./linux_6_16_tso/patches.nix;
    };
    linux_6_17_tso = patchKernel {
      original = linuxKernel.kernels.linux_6_17;
      patches = import ./linux_6_17_tso/patches.nix;
    };
  };
  packages = lib.recurseIntoAttrs (lib.mapAttrs (k: linuxKernel.packagesFor) kernels);
}
