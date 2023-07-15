{ lib, stdenv, fetchurl, p7zip }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz
  version = "23A5286i";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/46/17/042-13875-A_LVTMS3RTZV/wyr9cfk0a3q54xh5ros73kzipultu2inkd/RosettaUpdateAuto.pkg";
    hash = "sha256-5XbXWnV6uZBdGo72ZWoRohnkCwOU76xKOHgirV0qwOM=";
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
