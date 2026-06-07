[![Build and push to Cachix](https://github.com/AWildLeon/lh-nixlib/actions/workflows/build.yml/badge.svg)](https://github.com/AWildLeon/lh-nixlib/actions/workflows/build.yml)
[![Deploy options search to GitHub Pages](https://github.com/AWildLeon/lh-nixlib/actions/workflows/pages.yml/badge.svg)](https://github.com/AWildLeon/lh-nixlib/actions/workflows/pages.yml)

# lh-nixlib

Public, reusable NixOS modules, libraries and tooling extracted from my personal homelab flake.

My main flake contains a lot of internal tooling and infrastructure-specific stuff like host configs, network topology and internal services that I don't want to share publicly for privacy reasons. This repo is a public subset: things I'm happy to share with friends or anyone who finds it useful.

A lot of it is wrappers around nixpkgs under my own `lh.*` namespace. The idea is that you can import it and nothing breaks, in theory. In practice, no guarantees.

> Work in progress, stuff is added gradually.

Options: https://nixlib.onlh.de

## Support

No support. Issues will probably be ignored unless they personally bug me. If you want something fixed, open a PR.

Also, I use AI in here. There will be dragons.
Dont expect anything in here to be stable. I'll do as I please.

## License

This repository is licensed under the [MIT License](LICENSE).

> [!Note]
> MIT license does not apply to the packages built by this repository, merely to the files in this repository (the Nix expressions, build scripts, NixOS modules, etc.).
> It also might not apply to patches included in this repository, which may be derivative works of the packages to which they apply.
> The aforementioned artifacts are all covered by the licenses of the respective packages.
