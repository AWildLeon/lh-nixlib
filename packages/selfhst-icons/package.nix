{
  lib,
  fetchFromGitHub,
  nix-update-script,
  maintainers,
}:

fetchFromGitHub {
  pname = "selfhst-icons";
  version = "unstable";
  owner = "selfhst";
  repo = "icons";
  rev = "6e0e196eb824ba991eddf63e0975af0bd54bbf31";
  hash = "sha256-aH+KJJKxpPOWCN43Cf5H3NKuILxRkch8nwA0td3x/Xk=";

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  meta = {
    description = "Collection of icons and logos maintained by selfh.st";
    homepage = "https://selfh.st/icons";
    license = lib.licenses.cc-by-40;
    maintainers = [ maintainers.awildleon ];
    platforms = lib.platforms.all;
  };
}
