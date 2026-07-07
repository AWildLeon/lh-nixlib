{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
  maintainers,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dashboard-icons";
  version = "0-unstable-2026-06-12";

  src = fetchFromGitHub {
    owner = "homarr-labs";
    repo = "dashboard-icons";
    rev = "00c43aa6857e2905b1d59bfceddfca7bc145f44a";
    hash = "sha256-d3hvWlkxCXr5ZdPYer2g58CgN0uUYZYG4Ow5qHxkaYw=";
  };

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    cp -r . "$out"
  '';

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  meta = {
    description = "Your definitive source for dashboard icons";
    homepage = "https://dashboardicons.com";
    license = lib.licenses.asl20;
    maintainers = [ maintainers.awildleon ];
    platforms = lib.platforms.all;
  };
})
