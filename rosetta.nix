{ lib, stdenv, fetchurl, p7zip }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Sonoma Beta 5
  version = "23A5312d";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/53/07/042-27173-A_8ILCIMG702/13kfaoxmyw0zoxtn2hbhdq7kmlsru6998r/RosettaUpdateAuto.pkg";
    hash = "sha256-8YbvuB2n2o5hByDkx3WilunnCK4jKzv/oBhK6Eyg5ew=";
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
