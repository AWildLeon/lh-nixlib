{ inputs, ... }:
{
  # Aggregate NixOS module exposing all of lh-nixlib's modules.
  # Add module files to `imports` as they are created.
  flake = {
    imports = [
      ./profiles/part.nix
    ];

    nixosModule.default =
      { lib, ... }:
      {
        # Expose lh-nixlib's lib helpers (e.g. mkJailTmpfiles) to all modules
        # as the `lh.lib` module argument, mirroring the flake-parts wiring.
        _module.args.lh.lib = import ../lib { inherit lib; };

        # Expose lh-nixlib's OWN flake inputs (e.g. nixpkgs-master) to all
        # modules under a distinct name. The plain `inputs` arg is the
        # *consumer's* inputs (passed via specialArgs) and would shadow anything
        # we set here, so it cannot be relied on to carry lh-nixlib's inputs.
        _module.args."inputs-lhnixlib" = inputs;

        imports = [
          # External (Own) modules whose options lh-nixlib's services rely on.
          inputs.glance-ical-events.nixosModules.default

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
