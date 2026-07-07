{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
  maintainers,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "selfhst-icons";
  version = "0-unstable-2026-07-01";

  src = fetchFromGitHub {
    owner = "selfhst";
    repo = "icons";
    rev = "d3a5d5cca6581d643a9fc4266eaf85b0a24a7d68";
    hash = "sha256-cBAUtkNS4S0SL69+RwVOe/RBtoU5+kblgUBjY/TXTq4=";
  };

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    cp -r . "$out"
  '';

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  meta = {
    description = "Collection of icons and logos maintained by selfh.st";
    homepage = "https://selfh.st/icons";
    license = lib.licenses.cc-by-40;
    maintainers = [ maintainers.awildleon ];
    platforms = lib.platforms.all;
  };
})
