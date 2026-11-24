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

      # The board itself. NixOS configurations are built natively for this
      # platform, so `nixos-rebuild switch` on the board does not need any
      # x86_64 build tools (which it cannot run).
      hostSystem = "aarch64-linux";

      # The SD-card images are cross-compiled on a normal x86_64 machine, so
      # no emulation or second build machine is needed. This only applies to
      # the `packages` outputs; `nixosConfigurations` stays native.
      imageBuildSystem = "x86_64-linux";

      # U-Boot for the board. When buildSystem is x86_64, the aarch64 cross
      # package set is used; on the board itself the native package set has
      # everything needed (including the RK3588 BL31/TPL blobs).
      mkUboot =
        buildSystem:
        let
          buildPkgs = nixpkgs.legacyPackages.${buildSystem};
        in
        buildPkgs.callPackage ./hosts/orangepi5b/u-boot.nix {
          pkgsCross =
            if buildSystem == hostSystem then buildPkgs else buildPkgs.pkgsCross.aarch64-multiplatform;
        };

      mkSystem =
        {
          profile,
          buildSystem ? hostSystem,
        }:
        nixpkgs.lib.nixosSystem {
          # Must be null because the platform is set explicitly below.
          system = null;

          specialArgs = {
            inherit username initialPassword;
            uboot = mkUboot buildSystem;
          };

          modules = [
            {
              nixpkgs.buildPlatform = buildSystem;
              nixpkgs.hostPlatform = hostSystem;
            }
            ./hosts/orangepi5b/common.nix
            profile
          ];
        };

      # These are what `nixos-rebuild switch --flake .#orangepi5b-*` uses on
      # the board: buildPlatform == hostPlatform, i.e. a native build.
      server = mkSystem { profile = ./hosts/orangepi5b/server.nix; };
      full = mkSystem { profile = ./hosts/orangepi5b/full.nix; };

      # The same systems, cross-compiled for producing the SD-card images on
      # an x86_64 machine.
      imageServer = mkSystem {
        profile = ./hosts/orangepi5b/server.nix;
        buildSystem = imageBuildSystem;
      };
      imageFull = mkSystem {
        profile = ./hosts/orangepi5b/full.nix;
        buildSystem = imageBuildSystem;
      };

      devShells =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              rkdeveloptool
            ];
          };
        };
    in
    {
      nixosConfigurations = {
        orangepi5b-server = server;
        orangepi5b-full = full;
      };

      packages = {
        # Cross-compiled images, built on an x86_64 machine.
        ${imageBuildSystem} = {
          server = imageServer.config.system.build.sdImage;
          full = imageFull.config.system.build.sdImage;
          uboot = mkUboot imageBuildSystem;
        };

        # Building an image directly on the board also works, natively.
        ${hostSystem} = {
          server = server.config.system.build.sdImage;
          full = full.config.system.build.sdImage;
          uboot = mkUboot hostSystem;
        };
      };

      formatter = {
        ${imageBuildSystem} = nixpkgs.legacyPackages.${imageBuildSystem}.nixfmt;
        ${hostSystem} = nixpkgs.legacyPackages.${hostSystem}.nixfmt;
      };

      devShells = {
        ${imageBuildSystem} = devShells imageBuildSystem;
        ${hostSystem} = devShells hostSystem;
      };
    };
}
