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
        (mkSearch {
          title = "LH Nix Lib Options";

          modules = [
            self.nixosModule.default
          ];

          urlPrefix = "https://nixlib.onlh.de/";

          baseHref = "/";

          specialArgs = {
            inherit inputs pkgs;
          };
        }).overrideAttrs
          (old: {
            # Angular 22's @angular/build no longer copies symlinked assets
            # from public/ into the bundle, so the runtime data files
            # (index.ixx, meta) and the fixx wasm — all symlinks at build
            # time — go missing and the deployed page 404s on them. Copy the
            # dereferenced files into the output ourselves.
            postInstall = (old.postInstall or "") + ''
              cp -L public/fixx_bg.wasm public/index.ixx $out/
              cp -rL public/meta $out/meta
            '';
          });
    };
}
