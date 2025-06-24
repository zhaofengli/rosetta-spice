{ lib, stdenv, fetchurl, p7zip }:
let
  # https://swscan.apple.com/content/catalogs/others/index-rosettaupdateauto-1.sucatalog.gz

  # Tahoe 26.0 Developer Beta 2
  version = "25A5295e";
  src = fetchurl {
    url = "https://swcdn.apple.com/content/downloads/39/46/082-58036-A_WCOVJJIR7H/dmu2qq79qjdn85h8vd8hj09v26qlx5i7l4/RosettaUpdateAuto.pkg";
    hash = "sha256-SUeiaEiDMokhkRHrOmkWz+wRr/C98GyRczYlq2xr7bY=";
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
