{
  description = "A mess of NixOS configs";

  inputs = {

    # nix packages version
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  };
  
  outputs = inputs@{ nixpkgs, ... }: rec {

    # config with nixos-system
    nixosConfigurations.opi5b =
      nixpkgs.lib.nixosSystem {
        

        system = "x86_64-linux";

        # child inherit nixpkss
        specialArgs = {
          inherit nixpkgs;
        };

        modules = [
          {        
            # target system
            nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu";
          }
          # nixos-system
          ./orangepi5b.nix 
        ];
    };

    # build with "nix build #.opi5b"
    opi5b = nixosConfigurations.opi5b.config.system.build.sdImage;

  };
}

