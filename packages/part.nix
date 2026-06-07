_:
let
  maintainers = import ../maintainers;
in
{
  perSystem =
    { pkgsUnstable, ... }:
    {
      packages.traefik = import ./traefik/package.nix { inherit pkgsUnstable maintainers; };
    };
}
