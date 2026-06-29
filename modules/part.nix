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
