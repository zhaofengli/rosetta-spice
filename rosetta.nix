{ lib, stdenv, fetchurl, p7zip }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Sonoma Beta 4 (Release 2)
  version = "23A5301h";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/02/02/042-25565-A_7EXCGPSTS4/rmx0939ot0p4ussy957lns3cupaqwx76qx/RosettaUpdateAuto.pkg";
    hash = "sha256-G6ObxeJBFnZ8sZtwayYpKO12J86/kcnhGAG/JLbXh6g=";
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
