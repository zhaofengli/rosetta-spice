{ rosetta-spice, runCommandCC }:

rosetta:
runCommandCC "${rosetta.name}-patched" {
  nativeBuildInputs = [ rosetta-spice ];
} ''
  mkdir -p $out/bin
  for bin in rosetta rosettad; do
    if [[ -f "${rosetta}/bin/$bin" ]]; then
      rosetta-spice "${rosetta}/bin/$bin" "$out/bin/$bin"
    fi
  done
  chmod +x $out/bin/*
''
