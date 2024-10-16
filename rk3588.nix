{ pkgs, inputs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackagesFor (
      pkgs.buildLinux {
        version = "6.11.3";
        modDirVersion = "6.11.3";
        src = inputs.linux-rockchip-collabora;
        extraMeta.branch = "6.11";
      }
    );

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    growPartition = true;

    initrd.kernelModules = [
      "ahci_dwc"
      "phy_rockchip_naneng_combphy"
    ];
    consoleLogLevel = 7;
  };

  hardware.graphics.enable = true;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
}

