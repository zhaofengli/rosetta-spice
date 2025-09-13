{ lib, stdenv, fetchurl, p7zip, cpio }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Tahoe 26.0 RC
  version = "25A353";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/61/63/093-37146-A_S9OR0EVSU7/85gm90bhzh16fd705jb6sjc3unnywcu7xv/RosettaUpdateAuto.pkg";
    hash = "sha256-vNKVnLIZmxGhaCQk3CRvcu8i22QawSbMlcUfiFx33Xk=";
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
