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
      lib = nixpkgs.lib;

      # Generic defaults for a fresh installation: one normal user called
      # `nixos` with the password `nixos`. Change both values here (and change
      # the password on first login) when you make the image your own.
      defaultUsername = "nixos";
      defaultInitialPassword = "nixos";

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

      # The board modules, separated into fragments (for `lib.mkSystem`) and
      # complete modules (see `nixosModules` below). Keeping the common part
      # in one place is what lets the profiles stay small.
      profileModules = {
        common = ./hosts/orangepi5b/common.nix;
        server = ./hosts/orangepi5b/server.nix;
        full = ./hosts/orangepi5b/full.nix;
      };

      variants = {
        server = profileModules.server;
        full = profileModules.full;
      };

      mkSystem =
        {
          profile,
          buildSystem ? hostSystem,
          username ? defaultUsername,
          initialPassword ? defaultInitialPassword,
          extraModules ? [ ],
          extraSpecialArgs ? { },
        }:
        nixpkgs.lib.nixosSystem {
          # Must be null because the platform is set explicitly below.
          system = null;

          # Keep the old special arguments available for derivative modules,
          # while the board modules themselves use the orangepi5b.* options.
          specialArgs = {
            inherit username initialPassword;
            uboot = mkUboot buildSystem;
          }
          // extraSpecialArgs;

          modules = [
            {
              nixpkgs.buildPlatform = buildSystem;
              nixpkgs.hostPlatform = hostSystem;

              # These are board options, so they can also be overridden by an
              # `extraModules` entry. The U-Boot package must match the build
              # platform, which is why it is computed here.
              orangepi5b.uboot = lib.mkDefault (mkUboot buildSystem);
              orangepi5b.username = lib.mkDefault username;
              orangepi5b.initialPassword = lib.mkDefault initialPassword;
            }
            profileModules.common
            profile
          ]
          ++ extraModules;
        };

      mkConfigs =
        buildSystem:
        lib.mapAttrs (
          _name: profile:
          mkSystem {
            inherit profile buildSystem;
          }
        ) variants;

      nativeConfigs = mkConfigs hostSystem;
      crossConfigs = mkConfigs imageBuildSystem;

      # Complete modules for direct `imports = [ ... ]` use. They include
      # common.nix, so they do not need `lib.mkSystem` or special arguments.
      mkBoardModule = profiles: {
        imports = [ profileModules.common ] ++ profiles;
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
      # Reusable building blocks for derivative flakes. Use the fragments in
      # `lib.profiles` with `lib.mkSystem` when you need native/cross variants:
      #
      #   profile = orangepi5b-flake.lib.profiles.server;
      #   board = orangepi5b-flake.lib.mkSystem { inherit profile; };
      #
      # `lib.mkSystem` includes common.nix, the platform settings and the
      # matching U-Boot build.
      lib = {
        inherit
          hostSystem
          imageBuildSystem
          mkUboot
          mkSystem
          ;
        profiles = profileModules;
      };

      # Self-contained modules, for example:
      #
      #   nixosConfigurations.my-board = nixpkgs.lib.nixosSystem {
      #     modules = [
      #       { nixpkgs.hostPlatform = "aarch64-linux"; }
      #       orangepi5b-flake.nixosModules.server
      #     ];
      #   };
      #
      # They default `orangepi5b.uboot` to a package built for the current
      # build platform. Use `lib.mkSystem` if you also need the cross variant.
      nixosModules = {
        default = mkBoardModule [ profileModules.server ];
        common = profileModules.common;
        server = mkBoardModule [ profileModules.server ];
        full = mkBoardModule [ profileModules.full ];
      };

      nixosConfigurations =
        lib.mapAttrs' (name: config: lib.nameValuePair "orangepi5b-${name}" config) nativeConfigs
        // lib.mapAttrs' (name: config: lib.nameValuePair "orangepi5b-${name}-cross" config) crossConfigs;

      packages = {
        # Cross-compiled images, built on an x86_64 machine.
        ${imageBuildSystem} =
          lib.mapAttrs (_name: config: config.config.system.build.sdImage) crossConfigs
          // {
            uboot = mkUboot imageBuildSystem;
          };

        # Building an image directly on the board also works, natively.
        ${hostSystem} = lib.mapAttrs (_name: config: config.config.system.build.sdImage) nativeConfigs // {
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
