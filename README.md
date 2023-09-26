# rosetta-spice (WIP)

`rosetta-spice` patches [RosettaLinux](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta) to enable features and fix issues:

- Enables AOT caching without [involvement](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#4239539) of the virtualization app
    - This requires the RosettaLinux version from Sonoma
- Fixes segfaults when running patched binaries (https://github.com/NixOS/nixpkgs/issues/209242)
    - No longer needed since Sonoma Beta 5 (23A5312d)!
- Allows the use of another RosettaLinux version than what's supplied by the host

## Usage
Enable the NixOS module on the guest VM. The host MacOS machine does not need modification.

### Example System Flake

The NixOS module can be enabled on an `aarch64-linux` NixOS virtual machine via a configuration similar to the following:

```nix
{
  description = "System Configuration";

  inputs = {
     (...other inputs here...)
     rosetta-spice.url = "github:zhaofengli/rosetta-spice";
  };

  outputs = {rosetta-spice, ...}: {
    nixosConfiguration = {
      myHost = lib.nixosSystem {
        modules =
          [
            rosetta-spice.nixosModules.rosetta-spice
            (...other modules here...)
          ];
      };
    };
  };
}  
```

## Notes

This tool does _not_ bypass the licensing check.
You must mount the Rosetta share at `/run/rosetta` for this to work.
To quote the original message:

> Rosetta is only intended to run on Apple Silicon with a macOS host using Virtualization.framework with Rosetta mode enabled
