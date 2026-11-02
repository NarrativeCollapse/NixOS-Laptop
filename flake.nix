{
  description = "Minimal NixOS laptop: sway, Wayland only, offline-first";

  # The only input. flake.lock pins it to an exact commit, so nothing
  # changes until you run `nix flake update` yourself.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    {
      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        modules = [ ./configuration.nix ];
      };
    };
}
