{
  description = "A mess of NixOS configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu";

    linux-rockchip-collabora = {
      url = "github:K900/linux/rk3588-test";
      flake = false;
    };

  };
  
  outputs = inputs@{ nixpkgs, ... }: rec {

    # Config
    nixosConfigurations.opi5b =
      nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./orangepi5b.nix
        ];
    };

    # Orange Pi 5 SBC
    images.opi5b = nixosConfigurations.opi5b.config.system.build.sdImage;

  };
}

