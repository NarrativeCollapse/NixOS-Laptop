# PLACEHOLDER: replace this file on the laptop before installing:
#
#   nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
#
# It is only here so the flake evaluates and builds before you have the
# machine in front of you. The labels below match the partitioning steps
# in README.md, so it would boot, but the generated file also picks the
# right kernel modules and CPU microcode for your hardware.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];

  boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-label/cryptroot";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
