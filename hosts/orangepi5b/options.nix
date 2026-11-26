{ lib, pkgs, ... }:

let
  # U-Boot is needed at image-build time, so it must be built for the build
  # platform. With a native aarch64 configuration that is just the native
  # package set; when the NixOS configuration is cross-compiled on x86_64 we
  # use the aarch64 cross set from the build platform's package set.
  buildPkgs = pkgs.buildPackages;
  ubootPkgsCross =
    if buildPkgs.stdenv.hostPlatform.system == pkgs.stdenv.hostPlatform.system then
      buildPkgs
    else
      buildPkgs.pkgsCross.aarch64-multiplatform;

  defaultUboot = buildPkgs.callPackage ./u-boot.nix { pkgsCross = ubootPkgsCross; };
in
{
  options.orangepi5b = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = ''
        Initial normal user created for the board. Override this with
        `orangepi5b.username`, or through `lib.mkSystem`'s `username`
        argument, instead of copying the board modules.
      '';
    };

    initialPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "nixos";
      description = ''
        Initial password for `orangepi5b.username`. Change it on first login.
        Set to `null` to create the account without a password (for example
        when SSH keys are provisioned out of band).
      '';
    };

    uboot = lib.mkOption {
      type = lib.types.package;
      default = defaultUboot;
      description = ''
        U-Boot package whose `u-boot-rockchip.bin` is written into the SD/eMMC
        image. The default is a U-Boot built for the build platform; override
        it if you build U-Boot yourself.
      '';
    };
  };
}
