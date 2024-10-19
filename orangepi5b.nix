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
  	extraGroups  = [ "wheel" "networkmanager" "mpd" "input" "adbusers" "kvm" "docker" ];
	};

  # ENV VARS
  environment.sessionVariables = {
		GDK_BACKEND="wayland";
		QT_QPA_PLATFORM="wayland";
    MOZ_ENABLE_WAYLAND = "1";
    TERM = "foot";
    TERMINAL = "foot";
    BROWSER = "firefox";
    VISUAL = "nvim";
		NIXOS_OZONE_WL = "1";
		ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

	# steam
	programs.steam = {
  	enable = true;
  	remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  	dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  	localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
	};

	# firefox
	programs.firefox.enable = true;

	# hyprland
	programs.hyprland.enable = true;
	
	# adb
	programs.adb.enable = true;

  # Fish Shell
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;
  environment.shells = with pkgs; [ fish ];

  # Nvim default
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    configure = {
      customRC = ''
        set number
        set tabstop=2
				set shiftwidth=2
				set colorcolumn=75
      '';
    };
  };

  # Bootloader.
  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.canTouchEfiVariables = true;
  #boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "de_DE.utf8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # lightdm for greeter 
  services.xserver.displayManager.lightdm.enable = false;

  # Run GreetD on TTY2
  services.greetd = {
    enable = true;
    vt = 7;
    settings = {
      default_session = {
        command = "${lib.makeBinPath [pkgs.greetd.tuigreet] }/tuigreet --user-menu --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "de";
    xkb.variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    dina-font
    proggyfonts
    font-awesome
    meslo-lgs-nf
    ubuntu_font_family
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
  ];

  # XDG stuff
  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # Enable gvfs (mount, trash...) for thunar
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # enable GameMode
  programs.gamemode.enable = true;

	# enable Gamescope
	programs.gamescope.enable = true;
  
	# Docker
	virtualisation.docker.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
		yarn
		parted
		gparted
    wget
		minizip
    git
		git-lfs
    vulkan-tools
    vulkan-loader
    foot
    adwaita-icon-theme
    waybar
    grim
    slurp
    pipewire
    wireplumber
    pavucontrol
    xfce.thunar
    hyprpaper
		hyprcursor
    gnome-themes-extra
    vlc
    imv
    rofi-wayland
    ranger
    neofetch
    mpv
    mako
    p7zip
    unrar
    wl-clipboard
    brightnessctl
    killall
    playerctl
    mpc-cli
    unzip
    discord
    prismlauncher
    ffmpeg
    xarchiver
    obs-studio
    polkit
    polkit-kde-agent
		jdk
		element-desktop
		shotcut
		vscodium
		rkdeveloptool
		qemu
		screen
  ];

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

