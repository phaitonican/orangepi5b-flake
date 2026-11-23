{
  description = "NixOS images for the Orange Pi 5B (Rockchip RK3588S)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      # Generic defaults for a fresh installation: one normal user called
      # `nixos` with the password `nixos`. Change both values here (and change
      # the password on first login) when you make the image your own.
      username = "nixos";
      initialPassword = "nixos";

      # We cross-compile the aarch64 image on a normal x86_64 machine.
      buildSystem = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${buildSystem};

      # Upstream U-Boot has a device tree but no defconfig for the 5B, so it is
      # built from hosts/orangepi5b/u-boot/defconfig. The plain nixpkgs
      # ubootOrangePi5 package supplies the RK3588 BL31/TPL blobs.
      uboot = pkgs.callPackage ./hosts/orangepi5b/u-boot.nix {
        pkgsCross = pkgs.pkgsCross.aarch64-multiplatform;
      };

      mkSystem =
        profile:
        nixpkgs.lib.nixosSystem {
          # Must be null because the platform is set explicitly below.
          system = null;

          specialArgs = { inherit uboot username initialPassword; };

          modules = [
            {
              nixpkgs.buildPlatform = buildSystem;
              nixpkgs.hostPlatform = "aarch64-linux";
            }
            ./hosts/orangepi5b/common.nix
            profile
          ];
        };

      server = mkSystem ./hosts/orangepi5b/server.nix;
      full = mkSystem ./hosts/orangepi5b/full.nix;

      serverImage = server.config.system.build.sdImage;
      fullImage = full.config.system.build.sdImage;
    in
    {
      nixosConfigurations = {
        orangepi5b-server = server;
        orangepi5b-full = full;

        # Legacy aliases: the old single configuration was the full image.
        opi5b = full;
        orangepi5b = full;
      };

      packages.${buildSystem} = {
        # Keep `nix build` on the full image to avoid surprising existing
        # users. Use `nix build .#server` for the minimal image.
        default = fullImage;
        server = serverImage;
        full = fullImage;
        opi5b = fullImage;
        inherit uboot;
      };

      formatter.${buildSystem} = pkgs.nixfmt;

      devShells.${buildSystem}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          rkdeveloptool
        ];
      };
    };
}
