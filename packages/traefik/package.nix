{ pkgsUnstable, maintainers }:
pkgsUnstable.traefik.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname or "traefik"}-lh-patched";

  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/sockets.patch
  ];

  # The patch touches no go.mod/go.sum, so reuse the stock vendored modules:
  # with the renamed pname they would get a new store path no cache has, and
  # every builder would re-fetch them from proxy.golang.org (which CI runners
  # have been refused with 403).
  inherit (pkgsUnstable.traefik) goModules;

  meta = (oldAttrs.meta or { }) // {
    description = (oldAttrs.meta.description or "Traefik") + " (patched by lh-nixlib: sockets.patch)";
    maintainers = [ maintainers.awildleon ];
  };
})
