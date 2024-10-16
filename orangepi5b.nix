{
  config,
  lib,
  pkgs,
  inputs,
  ubootOrangePi5,
  ...
}: {
  imports = [ ./rk3588.nix ];

  hardware.deviceTree.name = "rockchip/rk3588s-orangepi-5b.dtb";

  system.build = {
    sdImage = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      name = "orangepi5-sd-image";
      copyChannel = false;
      inherit config lib pkgs;
    };
    # FIXME: replace with upstream after 2024.10 release
    # uboot = crossPkgs.callPackage ../../hacks/orangepi5/uboot { };
  };
}

