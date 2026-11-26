{
  config,
  pkgs,
  ...
}:

let
  # rkmon's upstream ldflags force a static external link, which fails when
  # cross-compiling because the static aarch64 libc/pthread are not available.
  # It is pure Go, so use the internal linker instead and set the version
  # metadata explicitly rather than filtering nixpkgs' flag list.
  rkmon = pkgs.rkmon.overrideAttrs (old: {
    env = (old.env or { }) // {
      CGO_ENABLED = "0";
    };
    ldflags = [
      "-s"
      "-w"
      "-X=main.Version=${old.version or "unknown"}"
      "-X=main.GitSHA=${old.src.rev or ""}"
    ];
  });
in
{
  imports = [ ./options.nix ];

  # Full media/NPU profile:
  # - HDMI 2.1 + Mali-G610 (Panthor) GPU
  # - mainline 3-core NPU (rocket) + Mesa rocket/Teflon userspace
  # - VPU121/AV1 decode and RGA 2D acceleration
  # - GPU firmware and RK3588 monitoring tools

  boot.kernelModules = [
    "rocket" # 3-core NPU (mainline accel driver)
    "panthor" # Mali-G610 GPU
    "rockchipdrm" # VOP2 + HDMI QP display controller
    "hantro-vpu" # VPU121 (H.264/VP8) and AV1 decoder
    "rockchip-rga" # 2D raster/RGA accelerator
  ];

  hardware = {
    # Only the hardware drivers are built; the full Mesa driver set and the
    # software rasterisers are omitted. Mesa still links libLLVM, but this is
    # far smaller than a stock Mesa closure. If the GPU ever fails to probe,
    # add "llvmpipe" back here.
    graphics = {
      enable = true;
      package =
        (pkgs.mesa.override {
          galliumDrivers = [
            "panfrost"
            "rocket"
          ];
          vulkanDrivers = [ "panfrost" ];
        }).overrideAttrs
          (old: {
            # VA-API's state tracker needs r600/radeonsi/nouveau/virgl, none of
            # which we build. Disable it or Mesa's configure step fails.
            mesonFlags = old.mesonFlags ++ [ "-Dgallium-va=disabled" ];
          });
    };
  };

  users.users.${config.orangepi5b.username}.extraGroups = [
    "video" # /dev/dri/card* (KMS/HDMI console)
    "render" # /dev/dri/renderD* (Panthor GPU)
    "audio" # HDMI/ES8388 audio devices
  ];

  environment.systemPackages = [
    rkmon # GPU/NPU/VPU/RGA/thermal monitor for RK3588
  ];

  system.nixos.tags = [ "full" ];
}
