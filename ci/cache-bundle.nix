# Aggregate derivation for warming our private Attic cache.
#
# It depends on every package we want cached, resolved from BOTH nixpkgs
# inputs pinned in this repo's flake.lock (via getFlake, not the ambient
# registry):
#   nixpkgs        -> stable channel
#   nixos-unstable -> unstable channel
#
# Building `bundle` therefore builds all of them in one go. Packages that
# are missing or broken in a given channel are skipped at eval time. To also
# skip packages that fail at *build* time, build with `nix build --keep-going`
# and push the realized `outPaths` (see .github/workflows/private_build.yml).
{
  system ? builtins.currentSystem,
}:
let
  flake = builtins.getFlake (toString ./..);

  pkgsFor =
    input:
    import flake.inputs.${input} {
      inherit system;
      config.allowUnfree = true;
    };

  stable = pkgsFor "nixpkgs";
  unstable = pkgsFor "nixos-unstable";
  inherit (stable) lib;

  # Attribute names to cache. claude-code-bin == claude-code and
  # winbox == winbox4 (identical store paths), so only one of each.
  names = [
    "anydesk"
    "brscan4"
    "claude-code"
    "discord"
    "gitkraken"
    "jetbrains-toolbox"
    "n8n"
    "spotify"
    "tk-safe"
    "vscode"
    "winbox4"
    "rustdesk"
    "rustdesk-flutter"
  ];

  # Keep only packages that both exist and evaluate to a buildable
  # derivation in this channel; anything missing or broken is dropped.
  pick =
    pkgs:
    lib.filter (d: d != null) (
      map (
        n:
        let
          v = pkgs.${n} or null;
        in
        if v == null then
          null
        else if (builtins.tryEval v.drvPath).success then
          v
        else
          null
      ) names
    );

  deps = pick stable ++ pick unstable;
in
{
  # The single derivation that depends on everything we want cached.
  bundle = stable.symlinkJoin {
    name = "private-cache-bundle";
    paths = deps;
  };

  # Flat list of output paths, used by CI to push exactly the packages
  # that actually built (resilient to per-package build failures).
  outPaths = map (d: d.outPath) deps;

  # Same, newline-separated, so CI can read it without a JSON parser.
  outPathsText = lib.concatStringsSep "\n" (map (d: d.outPath) deps);
}
