{
  description = "frozen's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure Boot (modules/system/secure-boot.nix)
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gruvbox-plus = {
      url = "github:FrozenCascade/gruvbox-plus-personal";
      flake = false;
    };
        cobalt = {
      url = "git+https://git.gianmarco.gg/gianmarco/cobalt";
      flake = false;
    };

    # Spotify with Spicetify (modules/applications/media.nix), and its Gruvbox theme
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gruvify = {
      url = "github:Skaytacium/Gruvify";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, stylix, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./hosts/elitebook
        home-manager.nixosModules.home-manager
        stylix.nixosModules.stylix
      ];
    };
  };
}
