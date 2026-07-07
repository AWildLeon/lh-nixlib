{
  lib,
  fetchurl,
  buildFHSEnv,
  libarchive,
  binutils,
  nix-update-script,
}:

let
  version = "2025.3.1.1";
  src = fetchurl {
    url = "https://cdn.devolutions.net/download/Linux/RDM/${version}/RemoteDesktopManager_${version}_amd64.deb";
    hash = "sha256-/tWWK3E4us8ZqiEw4uqIy41DYcPkoZWfKwYR6MPyuIM=";
  };

in
buildFHSEnv {
  pname = "remotedesktopmanager";
  inherit version;

  targetPkgs =
    pkgs: with pkgs; [
      libGL
      libdrm
      mesa
      libva
      udev
      libudev0-shim
      fontconfig

      libx11
      libice
      libxext
      libsm

      openssl
      gnutls
      zlib
      gss
      krb5
      cups
      icu
      gtk3
      vte
      glib
      glib-networking
      #libsoup_2_4
      libsoup_3
      webkitgtk_6_0
      webkitgtk_4_1
      lttng-ust_2_12
      libxcrypt-legacy

      powershell
      openssh
    ];

  profile = ''
    export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri
    export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d
    export LIBVA_DRIVERS_PATH=/run/opengl-driver/lib/dri
    export VDPAU_DRIVER_PATH=/run/opengl-driver/lib/vdpau
  '';

  extraInstallCommands = ''
    install -Dm755 "${./remotedesktopmanager.desktop}" "$out/share/applications/remotedesktopmanager.desktop"
    install -Dm644 "${./remotedesktopmanager.svg}" "$out/share/icons/hicolor/scalable/apps/remotedesktopmanager.svg"
  '';

  extraBuildCommands = ''
    "${binutils}/bin/ar" p "${src}" data.tar.xz | "${libarchive}/bin/bsdtar" -C "$out" -xp usr/
  '';

  runScript = "/usr/lib/devolutions/RemoteDesktopManager/RemoteDesktopManager";

  # No release feed to autodetect from; bump manually, e.g.:
  #   nix-update --flake remotedesktopmanager --version=2025.3.2.0
  passthru.updateScript = nix-update-script { };
}
