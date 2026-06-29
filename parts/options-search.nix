{ inputs, self, ... }:
{
  perSystem =
    {
      system,
      pkgs,
      ...
    }:
    let
      inherit (inputs.nuschtosSearch.packages.${system}) mkMultiSearch;

      urlPrefix = "https://github.com/AWildLeon/lh-nixlib/blob/main/";

    in
    {
      packages.options-search = mkMultiSearch {
        title = "LH Nix Lib Search";

        baseHref = "/";

        scopes = [
          {
            name = "Options";
            modules = [
              self.nixosModule.default
            ];
            inherit urlPrefix;
            specialArgs = {
              inherit inputs pkgs;
            };
          }
          {
            name = "Packages";
            # Index this flake's own packages. Drop options-search itself to
            # avoid referencing the derivation we are currently defining.
            pkgs = removeAttrs self.packages.${system} [ "options-search" ];
            inherit urlPrefix;
          }
        ];
      };
    };
}
