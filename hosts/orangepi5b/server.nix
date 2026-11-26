{
  lib,
  ...
}:

{
  # Minimal server profile:
  # - no Mesa/GPU stack
  # - no GPU/NPU/media kernel modules
  # - no GPU/NPU firmware beyond the shared linux-firmware/BCM43752 files
  # - no desktop, audio server or monitoring tools
  #
  # The common board configuration still gives you serial + HDMI console,
  # eMMC/SD, gigabit Ethernet, SSH, etc.
  hardware.graphics.enable = lib.mkDefault false;

  # Do not waste memory or log firmware errors on hardware this profile does
  # not use. Keep rockchipdrm loaded only for the simple HDMI text console.
  boot.blacklistedKernelModules = [
    "panthor"
    "rocket"
    "hantro-vpu"
    "rockchip-rga"
  ];

  system.nixos.tags = [ "server" ];
}
