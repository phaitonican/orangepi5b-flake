{
  pkgs,
  nixpkgs,
  lib,
  config,
  ...
}:
let

  u-boot = ./u-boot-new.bin;

in
{

  imports = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image.nix"
  ];

  nixpkgs.config.allowUnfree = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  hardware.deviceTree.name = "rockchip/rk3588s-orangepi-5b.dtb";
  hardware.enableAllFirmware = true;

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

    kernelParams = [
      "rootwait"

      "earlycon" # enable early console, so we can see the boot messages via serial port / HDMI
      "consoleblank=0" # disable console blanking(screen saver)
      "console=ttyS2,1500000" # serial port
      "console=tty1" # HDMI

      # docker optimizations
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      "swapaccount=1"
    ];

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
    isNormalUser = true;
    home = "/home/cenk";
    description = "Cenk";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  sdImage = {
    compressImage = false;

    # Gap in front of the /boot/firmware partition, in mebibytes (1024×1024 bytes).
    # Can be increased to make more space for boards requiring to dd u-boot SPL before actual partitions.
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "BOOT";
    firmwareSize = 200; # MiB

    populateFirmwareCommands = ''
      mkdir -p ./firmware
    '';

    #populateRootCommands = ''
    #  mkdir -p ./files/boot
    #'';

    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';

    # ???
    # image location(sector): 0x40 - u-boot.bin.
    postBuildCommands = ''
      # places the U-Boot image at block first at block 64 (0x40)
      dd if=${u-boot} of=$img seek=64 conv=notrunc
    '';
  };
  system.stateVersion = "25.05";
}
