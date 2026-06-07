_: {
  # Aggregate NixOS module exposing all of lh-nixlib's modules.
  # Add module files to `imports` as they are created.
  flake.nixosModule.default = {
    imports = [ ];
  };
}
