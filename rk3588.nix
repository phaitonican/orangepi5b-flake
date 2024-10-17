{ pkgs, ... }: let

    # custom kernel
    linux-rockchip-collabora = fetchGit {
        url = "https://gitlab.collabora.com/hardware-enablement/rockchip-3588/linux.git";
        rev = "ca520a6fda92e60490261aeb0b8a5725db1952da";
    };

in
{
  boot = {
    kernelPackages = pkgs.linuxPackagesFor (
      pkgs.buildLinux {
        version = "6.12.0";
        modDirVersion = "6.12.0-rc1";
        src = linux-rockchip-collabora;
        extraMeta.branch = "6.12";
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

