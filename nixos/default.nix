{ lib, pkgs, config, ... }:
let
  inherit (lib) types;

  cfg = config.virtualisation.rosetta-spice;
  flake = (import ../flake-compat.nix).defaultNix;

  rosetta = flake.packages.${pkgs.system}.rosetta;
  rosettaMountpoint = config.virtualisation.rosetta.mountPoint;
  rosettaPath =
    if cfg.rosettaPkg == null then "/run/rosetta-spice"
    else "${cfg.rosettaPkg}/bin";
in {
  options = {
    virtualisation.rosetta-spice = {
      enable = lib.mkOption {
        description = lib.mdDoc ''
          Whether to enable a patched version of RosettaLinux.
        '';
        type = types.bool;
        default = false;
      };
      enableAot = lib.mkOption {
        description = lib.mdDoc ''
          Whether to enable AOT translation if available.
        '';
        type = types.bool;
        default = true;
      };
      rosettaPkg = lib.mkOption {
        description = lib.mdDoc ''
          An alternative version of Rosetta to use.

          If not specified, the mounted Rosetta will be patched in an oneshot service.
        '';
        type = types.nullOr types.package;
        default = null;
      };
      package = lib.mkOption {
        internal = true;
        type = types.package;
        default = flake.packages.${pkgs.system}.rosetta-spice;
        defaultText = "(flake-provided rosetta-spice)";
      };
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.virtualisation.rosetta.enable;
          message = "virtualisation.rosetta-spice requires virtualisation.rosetta.enable";
        }
      ];

      virtualisation.rosetta.enable = lib.mkDefault true;
      boot.binfmt.registrations.rosetta = {
        interpreter = lib.mkForce "${rosettaPath}/rosetta";
      };
    }

    # Patch mounted Rosetta
    (lib.mkIf (cfg.rosettaPkg == null) {
      systemd.services.rosetta-spice = {
        wantedBy = [ "sysinit.target" ];
        after = [ "local-fs.target" ((lib.replaceStrings [ "/" ] [ "-" ] rosettaMountpoint) + ".mount") ];
        before = [ "systemd-binfmt.service" ]
          ++ lib.optional cfg.enableAot "rosettad.service";
        unitConfig = {
          DefaultDependencies = false;
        };
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "rosetta-spice";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = true;
        };
        path = [ cfg.package pkgs.gcc pkgs.coreutils ];
        script = ''
          set -euo pipefail
          for bin in rosetta rosettad; do
            if [[ -f "${rosettaMountpoint}/$bin" ]]; then
              rosetta-spice "${rosettaMountpoint}/$bin" "$RUNTIME_DIRECTORY/$bin.tmp"
              mv "$RUNTIME_DIRECTORY/$bin.tmp" "$RUNTIME_DIRECTORY/$bin"
            fi
          done

          if /run/current-system/systemd/bin/systemctl -q is-active systemd-binfmt.service; then
            >&2 echo "Restarting systemd-binfmt"
            /run/current-system/systemd/bin/systemctl restart --no-block systemd-binfmt.service
          fi
        '' + lib.optionalString cfg.enableAot ''
          if /run/current-system/systemd/bin/systemctl -q is-active rosettad.service; then
            >&2 echo "Restarting rosettad"
            /run/current-system/systemd/bin/systemctl restart --no-block rosettad.service
          fi
        '';
      };
    })

    # AOT
    (lib.mkIf cfg.enableAot {
      systemd.services.rosettad = {
        description = "Rosetta AOT translation daemon";
        wantedBy = [ "multi-user.target" ];
        after = lib.mkIf (cfg.rosettaPkg == null) [ ((lib.replaceStrings [ "/" ] [ "-" ] rosettaMountpoint) + ".mount") ];
        unitConfig = {
          ConditionPathExists = [ "${rosettaPath}/rosettad" ];
        };
        serviceConfig = {
          ExecStart = "${rosettaPath}/rosettad daemon $CACHE_DIRECTORY";

          User = "rosettad";
          DynamicUser = true;

          CacheDirectory = "rosettad";

          NoNewPrivileges = true;

          PrivateTmp = true;
          PrivateDevices = true;
          PrivateUsers = true;
          DevicePolicy = "closed";
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectKernelLogs = true;
          RestrictAddressFamilies = "AF_UNIX";
          LockPersonality = true;
        };
      };
    })
  ]);
}
