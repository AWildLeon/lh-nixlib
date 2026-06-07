{ pkgsUnstable, maintainers }:
pkgsUnstable.traefik.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname or "traefik"}-lh-patched";

  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/sockets.patch
  ];

  meta = (oldAttrs.meta or { }) // {
    description =
      (oldAttrs.meta.description or "Traefik")
      + " (patched by lh-nixlib: sockets.patch)";
    maintainers = [ maintainers.awildleon ];
  };
})
