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
      hasRosettaMount = lib.mkOption {
        description = lib.mdDoc ''
          Whether a host Rosetta virtiofs mount is available.

          The `rosetta` binary file in this virtiofs mount supports special ioctls
          which Rosetta uses to talk to the hypervisor.
          You can configure the mount with the `config.virtualisation.rosetta` options.

          If disabled, the kernel must have the TSO patches.
        '';
        type = types.bool;
        default = true;
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
      virtualisation.rosetta.enable = lib.mkDefault true;

      assertions = [
        {
          assertion = config.virtualisation.rosetta.enable == cfg.hasRosettaMount;
          message = ''
            The value of `virtualisation.rosetta.enable` must be the same as ahat of
            `virtualisation.rosetta-spice.hasRosettaMount`.

            In order to use Rosetta without a host Rosetta virtiofs mount, you
            must use a kernel which supports the `PR_GET_MEM_MODEL` (`0x6d4d444c`)
            prctl. This is highly recommended so TSO can be enabled on a per-thread
            basis.

            You can get the patches here: <https://github.com/AsahiLinux/linux/tree/bits/220-tso>
          '';
        }
        {
          assertion = !cfg.hasRosettaMount -> (cfg.rosettaPkg != null);
          message = ''
            `virtualisation.rosetta-spice.rosettaPkg` must be set to use
            `virtualisation.rosetta-spice.hasRosettaMount = false`.
          '';
        }
      ];
    }

    # Upstream Rosetta module
    (lib.mkIf (config.virtualisation.rosetta.enable) {
      boot.binfmt.registrations.rosetta = {
        interpreter = lib.mkForce "${rosettaPath}/rosetta";
      };
    })

    # No upstream Rosetta
    # Adapted from nixpkgs/nixos/modules/virtualisation/rosetta.nix
    (lib.mkIf (!config.virtualisation.rosetta.enable) {
      boot.binfmt.registrations.rosetta = {
        interpreter = "${rosettaPath}/rosetta";

        # The required flags for binfmt are documented by Apple:
        # https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta
        magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'';
        mask = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
        fixBinary = true;
        matchCredentials = true;
        preserveArgvZero = false;

        # Remove the shell wrapper and call the runtime directly
        wrapInterpreterInShell = false;
      };

      nix.settings = {
        extra-platforms = [ "x86_64-linux" ];
      };
    })

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
