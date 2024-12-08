{ lib, stdenv, fetchurl, p7zip }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Sequoia 15.2 Beta 3
  version = "24C5079e";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/38/30/072-18030-A_FANJVJ91EE/eeicx7eyga9aqrh2b3uif0yxqw7rn8dfuw/RosettaUpdateAuto.pkg";
    hash = "sha256-rmShRTbhbMf+mKsQiKMss8uspnudnPeuxukcqCDY2wc=";
  };

  drv = stdenv.mkDerivation {
    pname = "rosetta";
    inherit version src;

    nativeBuildInputs = [ p7zip ];

    unpackPhase = ''
      runHook preUnpack

      7z x $src
      7z x Payload\~

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
