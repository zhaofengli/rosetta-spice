let
  flake = (import ../flake-compat.nix).defaultNix;
  pkgs = import flake.inputs.nixpkgs.outPath {
    overlays = [];
  };

  linux = pkgs.linuxPackages_latest.kernel;
in pkgs.runCommand "linux-nolibc-${linux.version}" {
  inherit (linux) src;
  nativeBuildInputs = [ pkgs.git ];
} ''
  tar xvf $src --wildcards '*/tools/include/nolibc/*.h' --strip-components=3
  cp -r nolibc{,.orig}

  mkdir -p $out
  cp -r nolibc $out

  echo '# Vendored from Linux ${linux.version} (${linux.src.url})' >$out/nolibc/vendor.patch
  git diff --no-index nolibc.orig nolibc >>$out/nolibc/vendor.patch || true
''
