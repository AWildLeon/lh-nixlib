{ pkgs, maintainers }:
pkgs.glance.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname or "glance"}-lh-patched";

  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/sockets.patch
    ./patches/sockets-mode.patch
  ];

  meta = (oldAttrs.meta or { }) // {
    description =
      (oldAttrs.meta.description or "Glance")
      + " (patched by lh-nixlib: sockets.patch, sockets-mode.patch)";
    maintainers = [ maintainers.awildleon ];
  };
})
