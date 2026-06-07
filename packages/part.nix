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
    };
}
