# rosetta-spice (WIP)

`rosetta-spice` patches [RosettaLinux](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta) to enable features and fix issues:

- Enables AOT caching without [involvement](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#4239539) of the virtualization app
    - This requires the RosettaLinux version from Sonoma
- Fixes segfaults when running patched binaries (https://github.com/NixOS/nixpkgs/issues/209242)
    - No longer needed since Sonoma Beta 5 (23A5312d)!
- Allows the use of another RosettaLinux version than what's supplied by the host

## Notes

This tool does _not_ bypass the licensing check.
You must mount the Rosetta share at `/run/rosetta` for this to work.
To quote the original message:

> Rosetta is only intended to run on Apple Silicon with a macOS host using Virtualization.framework with Rosetta mode enabled
