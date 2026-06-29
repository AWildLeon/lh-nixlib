_:
let
  maintainers = import ../maintainers;
in
{
  perSystem =
    { pkgs, pkgsUnstable, ... }:
    {
      packages.traefik = import ./traefik/package.nix { inherit pkgsUnstable maintainers; };
      packages.glance = import ./glanceapp/package.nix { inherit pkgs maintainers; };
      packages.dashboard-icons = pkgs.callPackage ./dashboard-icons/package.nix { inherit maintainers; };
      packages.selfhst-icons = pkgs.callPackage ./selfhst-icons/package.nix { inherit maintainers; };

    };
}
