{ pkgs, nixpkgs, lib, ... }:
{

    imports = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image.nix"
    ];

    boot.kernelPackages = pkgs.linuxPackages_latest;

    nix.settings = {
        experimental-features = ["nix-command" "flakes"];
    };

    hardware.deviceTree.name = "rockchip/rk3588s-orangepi-5b.dtb";

    boot = {
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
    };

    hardware.graphics.enable = true;

    environment.systemPackages = with pkgs; [
        git # used by nix flakes
        curl
        openssl
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
        hashedPassword = "$7$CU..../....fl8o80QpEM2Ro0B.E5MOF1$j2/9oN2UCciyxJxpaZE1Ta.V1ncHOHwb.W8mQ6C3Bj/"; # "test"
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

        populateFirmwareCommands = ''
            mkdir -p ./firmware
        '';

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
    system.stateVersion = "22.11";
}
