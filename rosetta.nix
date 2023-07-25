{ lib, stdenv, fetchurl, p7zip }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Sonoma Beta 4
  version = "23A5301g";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/02/25/042-16906-A_6N49RSTBN4/38f7ijbgxskd1v7njzvkz20e5mcc4nzq6l/RosettaUpdateAuto.pkg";
    hash = "sha256-zzgBMdt06KCqA6lYqcvFrsFbxMVf7rd5tT6fYV9YqWE=";
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
