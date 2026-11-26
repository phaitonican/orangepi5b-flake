{
  config,
  lib,
  modulesPath,
  pkgs,
  uboot,
  username,
  initialPassword,
  ...
}:

let
  # U-Boot built from upstream U-Boot v2026.10 (see u-boot.nix). The combined
  # u-boot-rockchip.bin contains the idbloader and the U-Boot FIT and is
  # written at sector 64 (32 KiB), which is why the first partition starts at
  # 32 MiB.
  u-boot = "${uboot}/u-boot-rockchip.bin";

  # BCM43752/AP6275P firmware. linux-firmware still does not ship these, so
  # take the vendor files pinned to a specific orangepi-xunlong/firmware
  # revision. This provides the missing brcmfmac43752-pcie.* and the
  # BCM4362A2 Bluetooth patch file.
  brcm43752Firmware = pkgs.runCommand "brcmfmac43752-firmware" { } ''
    install -Dm644 ${
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/orangepi-xunlong/firmware/dc163b0ed2e0272d9ee31977a0e0a04884f0ae61/brcm/brcmfmac43752-pcie.bin";
        hash = "sha256-ai2+AeciId77qRpS4Vh2jZc6PIXKLYgckkN541rTayM=";
      }
    } $out/lib/firmware/brcm/brcmfmac43752-pcie.bin

    install -Dm644 ${
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/orangepi-xunlong/firmware/dc163b0ed2e0272d9ee31977a0e0a04884f0ae61/brcm/brcmfmac43752-pcie.txt";
        hash = "sha256-tHgPe4alaA2+SWgV2+B6oiAQcB3i2MYFcLgnSkLbIVs=";
      }
    } $out/lib/firmware/brcm/brcmfmac43752-pcie.txt

    install -Dm644 ${
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/orangepi-xunlong/firmware/dc163b0ed2e0272d9ee31977a0e0a04884f0ae61/brcm/brcmfmac43752-pcie.clm_blob";
        hash = "sha256-2BuorcizvApViRRrMbwxgSJpPYoRalAo0/6CZVbFqSo=";
      }
    } $out/lib/firmware/brcm/brcmfmac43752-pcie.clm_blob

    install -Dm644 ${
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/orangepi-xunlong/firmware/dc163b0ed2e0272d9ee31977a0e0a04884f0ae61/brcm/BCM4362A2.hcd";
        hash = "sha256-GJAaW+8dQYtolektCvrjYjT0FgsjdGXfyj116YROk+8=";
      }
    } $out/lib/firmware/brcm/BCM4362A2.hcd
  '';
in
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  # ---------------------------------------------------------------------------
  # Kernel / boot
  # ---------------------------------------------------------------------------

  boot = {
    # Latest mainline kernel from nixos-unstable. It has the RK3588S and
    # Orange Pi 5B device trees, Panthor/Panfrost GPU support, and the RK3588
    # eMMC driver.
    kernelPackages = pkgs.linuxPackages_latest;

    # Wi-Fi and Bluetooth on the 5B are not described by the upstream device
    # tree yet. The patch only touches rk3588s-orangepi-5b.dts, so the kernel
    # rebuilds its DTB with the AP6275P nodes included.
    kernelPatches = [
      {
        name = "orangepi-5b-wifi-bluetooth";
        patch = ./patches/0001-arm64-dts-rockchip-Enable-Wi-Fi-and-Bluetooth-on-Ora.patch;
      }
    ];

    kernelParams = [
      "rootwait"
      "earlycon" # early serial output on the 3-pin UART header
      "consoleblank=0"
      "console=ttyS2,1500000" # UART
      "console=tty1" # HDMI, harmless on a headless box
    ];

    # The Broadcom WiFi/Bluetooth modules are loaded ahead of mainline DT
    # support, so the software stack is complete when the radio is described.
    kernelModules = [
      "brcmfmac"
      "brcmutil"
      "bluetooth"
      "hci_uart"
      "btbcm"
      "btusb"
    ];

    # sd-image.nix pulls in the "all hardware" profile. The board only needs
    # the MMC/eMMC block driver to mount its root filesystem, so keep the
    # initrd tiny and predictable.
    initrd.includeDefaultModules = false;
    # Add "nvme" if you move the root filesystem to an M.2 SSD.
    initrd.availableKernelModules = [ "mmc_block" ];
    initrd.kernelModules = [ "dm_mod" ];

    # Add "btrfs"/"xfs" here if you use those on external disks.
    supportedFilesystems = [
      "ext4"
      "vfat"
    ];

    loader = {
      grub.enable = false;
      timeout = 0; # boot the default generation immediately
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 5;
      };
    };

    # Grow the root partition to fill the eMMC/SD card on boot. sd-image.nix's
    # own expand-root-partition service uses partprobe, which cannot re-read
    # the partition table while the root partition is mounted, so it silently
    # did nothing on this board. growpart uses a per-partition kernel ioctl
    # instead and works on a live root; it is a no-op once the partition fills
    # the disk.
    growPartition = true;
  };

  hardware = {
    deviceTree = {
      enable = true;
      name = "rockchip/rk3588s-orangepi-5b.dtb";
    };

    # WiFi/Bluetooth stack is enabled in software for both profiles. The
    # BCM43752/AP6275P enumerates over PCIe, but linux-firmware does not ship
    # its firmware yet, so the vendor brcmfmac43752-pcie.* files and the
    # BCM4362A2 Bluetooth patch are added separately.
    firmware = [ brcm43752Firmware ];
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
    bluetooth.enable = true;

    # sd-image.nix pulls in the all-hardware profile. The board only needs
    # its specific device tree, so opt out globally.
    enableAllHardware = lib.mkForce false;
  };

  powerManagement.cpuFreqGovernor = "schedutil";

  # ---------------------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------------------

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # ---------------------------------------------------------------------------
  # Networking / services
  # ---------------------------------------------------------------------------

  networking.hostName = "orangepi5b";

  # WiFi/BT management in software. NetworkManager also sets the wireless
  # regulatory domain and pulls in wpa_supplicant.
  networking.networkmanager.enable = true;

  # brcmfmac's power save on the AP6275P makes the link drop frames and adds
  # multi-100 ms latency spikes, which stalls TCP sessions (SSH freezes) on an
  # otherwise healthy connection. The board is mains-powered, so keep the
  # radio awake.
  networking.networkmanager.wifi.powersave = false;

  services.openssh = {
    # Not part of a stock NixOS install, but the only way to administer a
    # headless board. Password authentication is left at the NixOS default
    # (enabled) so the initial login works; add an SSH key and turn it off
    # once you are set up.
    enable = true;
    openFirewall = true;
  };

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  # A single generic user, like the `nixos` user on the installation media.
  # Change `username` and `initialPassword` in flake.nix, and change the
  # password after the first login.
  #
  # No SSH keys are trusted by default. Add your own public key in a
  # derivative of this flake, for example:
  #
  #   users.users.${username}.openssh.authorizedKeys.keys = [
  #     "ssh-ed25519 AAAA... you@example"
  #   ];
  #   users.users.root.openssh.authorizedKeys.keys = [
  #     "ssh-ed25519 AAAA... you@example"
  #   ];
  #
  # The `root` key is what `nixos-rebuild --target-host root@...` uses (see
  # "Deploy over the network" in README.md). Set
  # `services.openssh.settings.PasswordAuthentication = false` once key login
  # works.
  users.users.${username} = {
    isNormalUser = true;
    description = "NixOS User";
    initialPassword = initialPassword;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # ---------------------------------------------------------------------------
  # SD/eMMC image
  # ---------------------------------------------------------------------------

  # Let systemd grow the ext4 root filesystem after growpart has enlarged the
  # partition (see boot.growPartition). Both steps are no-ops once grown.
  fileSystems."/".autoResize = true;

  sdImage = {
    compressImage = false;

    # boot.growPartition + fileSystems."/".autoResize replace the one-shot
    # first-boot expansion, which silently did nothing on this board.
    expandOnBoot = false;

    # U-Boot lives in the gap before the first partition. 32 MiB is plenty
    # for the ~10 MiB u-boot-rockchip.bin.
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "BOOT";
    firmwareSize = 16; # the FAT partition is unused by this board

    # The FAT partition is only a placeholder on this board; /boot lives on
    # the ext4 root partition.
    populateFirmwareCommands = "";

    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -c ${config.system.build.toplevel} -d ./files/boot
    '';

    # The upstream-built `u-boot-rockchip.bin` combines the idbloader and the
    # U-Boot FIT; it is written at sector 64 (32 KiB / 0x40).
    postBuildCommands = ''
      dd if=${u-boot} of=$img bs=512 seek=64 conv=notrunc,fsync status=none
    '';
  };

  system.stateVersion = "26.11";
}
