{ pkgs, nixpkgs, lib, ... }: let

    # custom kernel
    linux-rockchip-collabora = fetchGit {
        url = "https://anongit.freedesktop.org/git/drm/drm-misc.git";
        rev = "dadd28d4142f9ad39eefb7b45ee7518bd4d2459c";
        ref = "drm-misc-next";
    };

		hashedPassword = "$7$CU..../....fl8o80QpEM2Ro0B.E5MOF1$j2/9oN2UCciyxJxpaZE1Ta.V1ncHOHwb.W8mQ6C3Bj/"; # "test"

in
{

  imports = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  hardware.deviceTree.name = "rockchip/rk3588s-orangepi-5b.dtb";

  boot = {
    kernelPackages = pkgs.linuxPackagesFor (
      pkgs.buildLinux {
        version = "6.12.0-rc2";
        modDirVersion = "6.12.0-rc2";
        src = linux-rockchip-collabora;
        extraMeta.branch = "6.12";
      }
    );

    kernelPatches = [ {
        name = "hdmi-config";
        patch = null;
        extraStructuredConfig = {
          DRM_DW_HDMI_QP = lib.kernel.yes;
					ROCKCHIP_DW_HDMI_QP = lib.kernel.yes;
        };
    } ];

    # fix zfs broken module
    supportedFilesystems = lib.mkForce [
      "vfat"
      "fat32"
      "exfat"
      "ext4"
      "btrfs"
    ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    growPartition = true;
  };

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    git # used by nix flakes
    curl
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      X11Forwarding = lib.mkDefault true;
      PasswordAuthentication = lib.mkDefault true;
    };
    openFirewall = lib.mkDefault true;
  };

	# Define user 
	users.users.cenk = {
		inherit hashedPassword;
  	isNormalUser  = true;
  	home  = "/home/cenk";
  	description  = "Cenk";
  	extraGroups  = [ "wheel" "networkmanager" ];
	};

  sdImage = {
    compressImage = true;

    # Gap in front of the /boot/firmware partition, in mebibytes (1024×1024 bytes).
    # Can be increased to make more space for boards requiring to dd u-boot SPL before actual partitions.
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "BOOT";
    firmwareSize = 200; # MiB

    populateRootCommands = ''
      mkdir -p ./files/boot
    '';

    # ???
    # image location(sector): 0x40 - u-boot.bin.
    postBuildCommands = ''
      # places the U-Boot image at block first at block 64 (0x40)
      dd if=${pkgs.ubootOrangePi5}/u-boot-rockchip.bin of=$img seek=64 conv=notrunc
    '';
  };

}

