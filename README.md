# rosetta-spice (WIP)

`rosetta-spice` patches [RosettaLinux](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta) to enable features and fix issues:

- Enables AOT caching without [involvement](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#4239539) of the virtualization app
    - This requires the RosettaLinux version from Sonoma
- Fixes segfaults when running patched binaries (https://github.com/NixOS/nixpkgs/issues/209242)
    - No longer needed since Sonoma Beta 5 (23A5312d)!
- Allows the use of another RosettaLinux version than what's supplied by the host

## Usage
Enable the NixOS module on the guest VM. The host macOS machine does not need modification.

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

You must either mount the Rosetta share at `/run/rosetta` or use [this patchset](https://patchwork.kernel.org/project/linux-arm-kernel/cover/20240411-tso-v1-0-754f11abfbff@marcan.st/) for this to work.
In both cases, a 4K kernel is required.

As of 24C5079e, RosettaLinux attempts to enable per-thread TSO with the following:

- `prctl(0x4d4d444c /* PR_SET_MEM_MODEL */, 0x1, 0, 0, 0)`, defined in [this proposed patchset](https://patchwork.kernel.org/project/linux-arm-kernel/cover/20240411-tso-v1-0-754f11abfbff@marcan.st/) shipped with Asahi Linux
- `ioctl(fd, _IOC(_IOC_NONE, 0x61, 0x24, 0), 0)` on the virtfs-mounted `rosetta` binary

