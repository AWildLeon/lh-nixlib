{ pkgsUnstable, maintainers }:
pkgsUnstable.traefik.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname or "traefik"}-lh-patched";

  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/sockets.patch
  ];

  # Keep upstream's vendor tree. Left alone, goModules follows the pname and
  # the patches above, so it becomes a fixed-output derivation under a name no
  # binary cache has, and every traefik bump refetches ~all of lego's
  # providers from proxy.golang.org on the builder (which then has to reach
  # storage.googleapis.com for the big zips). The output is the same bytes
  # either way — sockets.patch touches neither go.mod nor go.sum; a patch that
  # does must drop this line and set its own vendorHash.
  inherit (pkgsUnstable.traefik) goModules;

  meta = (oldAttrs.meta or { }) // {
    description = (oldAttrs.meta.description or "Traefik") + " (patched by lh-nixlib: sockets.patch)";
    maintainers = [ maintainers.awildleon ];
  };
})
