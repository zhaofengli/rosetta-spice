{ lib, stdenv, fetchurl, p7zip, cpio }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Tahoe 26.7.2
  version = "25G330";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/13/21/142-43923-A_EPTPMZZQAI/x2z47nvhykk47sl3qs7iam3bmv5l2rflu6/RosettaUpdateAuto.pkg";
    hash = "sha256-6ampDfe+MI/tMtp3kM5yt2GrvSzMmltne4CtElv/wI0=";
  };

  drv = stdenv.mkDerivation {
    pname = "rosetta";
    inherit version src;

    nativeBuildInputs = [ p7zip cpio ];

    unpackPhase = ''
      runHook preUnpack

      7z x $src
      cpio -idmv <Payload\~

      runHook postUnpack
    '';

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp Library/Apple/usr/libexec/oah/RosettaLinux/* $out/bin
      chmod +x $out/bin/*

      runHook postInstall
    '';

    dontFixup = true;
  };
in drv
