{ inputs, self, ... }:
{
  perSystem =
    {
      system,
      pkgs,
      ...
    }:
    let
      inherit (inputs.nuschtosSearch.packages.${system}) mkSearch;
    in
    {
      packages.options-search =
        mkSearch {
          title = "LH Nix Lib Options";

          modules = [
            self.nixosModule.default
          ];

          urlPrefix = "https://nixlib.onlh.de/";

          baseHref = "/";

          specialArgs = {
            inherit inputs pkgs;
          };
        };
    };
}
