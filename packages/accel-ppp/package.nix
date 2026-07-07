{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  openssl,
  pcre2,
  nix-update-script,
  maintainers,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "accel-ppp";
  version = "1.14.0";

  src = fetchFromGitHub {
    owner = "accel-ppp";
    repo = "accel-ppp";
    tag = finalAttrs.version;
    hash = "sha256-7MamSIXix6eGocJep1ihK//yRfJ9e3kLzMZV7I5DFQc=";
  };

  # drop the top-level CMakeLists.txt rule that installs straight to the
  # absolute path /var/log/accel-ppp; accel-pppd/CMakeLists.txt already
  # creates the same (relocatable) dir under CMAKE_INSTALL_LOCALSTATEDIR.
  postPatch = ''
    sed -i '/install(DIRECTORY DESTINATION \/var\/log\/accel-ppp)/d' CMakeLists.txt
  '';

  nativeBuildInputs = [ cmake ];
  buildInputs = [
    openssl
    pcre2
  ];

  cmakeFlags = [
    (lib.cmakeBool "IGNORE_GIT" true)
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Server for PPPoE, PPTP, L2TP, SSTP and IPoE tunnel protocols";
    homepage = "https://github.com/accel-ppp/accel-ppp";
    changelog = "https://github.com/accel-ppp/accel-ppp/blob/${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.gpl2Only;
    maintainers = [ maintainers.awildleon ];
    platforms = lib.platforms.linux;
    mainProgram = "accel-pppd";
  };
})
