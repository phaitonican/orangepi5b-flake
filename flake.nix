{
  description = "A mess of NixOS configs";

  inputs = {

    # nix packages version
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";


  };
  
  outputs = inputs@{ nixpkgs, ... }: rec {

    # config with nixos-system
    nixosConfigurations.opi5b =
      nixpkgs.lib.nixosSystem {
        
        # needed
        specialArgs = {
          inherit inputs;
        };

        modules = [
          {        
            # cross compile
            nixpkgs.hostPlatform.system = "aarch64-linux";
            nixpkgs.buildPlatform.system = "x86_64-linux";
          }
          # nixos-system
          ./orangepi5b.nix 
        ];
    };

    # build with "nix build #.opi5b"
    opi5b = nixosConfigurations.opi5b.config.system.build.sdImage;

  };
}

