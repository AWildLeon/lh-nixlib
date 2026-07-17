_:
let
  maintainers = import ../maintainers;
in
{
  perSystem =
    {
      lib,
      pkgs,
      pkgsUnstable,
      ...
    }:
    {
      packages.traefik = import ./traefik/package.nix { inherit pkgsUnstable maintainers; };
      packages.glance = import ./glanceapp/package.nix { inherit pkgs maintainers; };
      packages.dashboard-icons = pkgs.callPackage ./dashboard-icons/package.nix { inherit maintainers; };
      packages.selfhst-icons = pkgs.callPackage ./selfhst-icons/package.nix { inherit maintainers; };

      #packages.linux-lts-desktop-lhmod = pkgs.callPackage ./linux-lts-desktop-lhmod/package.nix { };
      #packages.linux-lts-server-lhmod = pkgs.callPackage ./linux-lts-server-lhmod/package.nix { };
      # NOTE: import directly, NOT via callPackage. callPackage makes the
      # wrapper lambda the `.override` target, which shadows linux_6_18's own
      # makeOverridable — so the nixos kernel module's re-override
      # (system/boot/kernel.nix: kernelPackages.apply) loses linux_6_18's
      # default kernelPatches/features and rebuilds a different kernel than
      # what CI cached. Importing straight through keeps `.override` == the
      # kernel's, making the module's re-override a hash-stable no-op.
      packages.linux-lts-router-lhmod = import ./linux-lts-router-lhmod/package.nix {
        inherit (pkgs) lib linux_6_18;
      };

      # Whole kernel package SET, the way nixpkgs registers kernels
      # (recurseIntoAttrs so `nix build …#legacyPackages.<sys>.<set>.<attr>`
      # walks kernel + out-of-tree modules — zfs, etc). Hosts consume this set
      # directly as `boot.kernelPackages`, instead of each calling
      # `pkgs.linuxPackagesFor` themselves, so the exact set CI builds and
      # caches is the one deployed.
      legacyPackages.linuxPackages-lts-router-lhmod = lib.recurseIntoAttrs (
        pkgs.linuxPackagesFor (
          import ./linux-lts-router-lhmod/package.nix {
            inherit (pkgs) lib linux_6_18;
          }
        )
      );

      packages.accel-ppp = pkgs.callPackage ./accel-ppp/package.nix { inherit maintainers; };
    };
}
