_: {
  # Aggregate NixOS module exposing all of lh-nixlib's modules.
  # Add module files to `imports` as they are created.
  flake = {
    imports = [
      ./profiles/part.nix
    ];

    nixosModule.default = {
      imports = [
        ./cosmetic
        ./hardware
        ./networking
        ./programs
        ./services
        ./security
        ./services
        ./system
        ./virtualization
        ./hardware
      ];
    };
  };
}
