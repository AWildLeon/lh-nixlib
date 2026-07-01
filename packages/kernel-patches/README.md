# Vendored kernel patches

Patch files downloaded from upstream and committed here so builds have no
runtime network dependency.  Run `update-patches.sh` to refresh.

---

## zen-sauce

**Source:** <https://github.com/zen-kernel/zen-kernel/commits/6.18/zen-sauce>  
**License:** GPL-2.0-only — see [`zen-sauce/COPYING`](zen-sauce/COPYING)  
**Tip commit:** `0c87fdcd1f9f7f1a09e8928422160159b8966784` (2026-02-14)

Desktop-interactivity patches by the zen-kernel project.  Applied on top of
the nixpkgs `linux_6_18` stable source.

To update: find newer commits on the `6.18/zen-sauce` branch, add their SHA
to the `update-patches.sh` fetch list, and re-run the script.

| File | Upstream commit |
|------|----------------|
| `zen-sauce/zen-interactive-base.patch` | `eb977217` |
| `zen-sauce/zen-ahci-disable-staggered-spinup.patch` | `081953d7` |
| `zen-sauce/zen-kswapd-early-stop.patch` | `c3f4f675` |
| `zen-sauce/zen-max-map-count.patch` | `4ad82553` |
| `zen-sauce/zen-kconfig-preempt-rt-no-expert.patch` | `85a8f552` |
| `zen-sauce/zen-mm-disable-watermark-boosting.patch` | `a958950c` |
| `zen-sauce/zen-mm-disable-swap-readahead.patch` | `106748e1` |
| `zen-sauce/zen-interactive-disable-split-lock.patch` | `0c87fdcd` |

---

## XanMod

**Source:** <https://gitlab.com/xanmod/linux-patches>  
**License:** GPL-2.0-only — see [`xanmod/LICENSE`](xanmod/LICENSE)  
**Pinned commit:** `16b5ed95569b7b66889cf34ee233a83aac9df307`

Network and performance patches from the XanMod project (`linux-6.18.y-xanmod`).

To update, get the new master SHA:
```sh
curl -s "https://gitlab.com/api/v4/projects/xanmod%2Flinux-patches/repository/commits?ref_name=master&per_page=1" \
  | jq -r '.[0].id'
```
Replace `XANMOD_COMMIT` in `update-patches.sh` and re-run.

| File | Upstream path |
|------|--------------|
| `xanmod/clearlinux/0001-sched-wait-*.patch` | `clearlinux/0001-…` |
| `xanmod/clearlinux/0002-firmware-*.patch` | `clearlinux/0002-…` |
| `xanmod/clearlinux/0003-locking-rwsem-*.patch` | `clearlinux/0003-…` |
| `xanmod/clearlinux/0004-drivers-ata-*.patch` | `clearlinux/0004-…` |
| `xanmod/net/netfilter/0001-netfilter-fullcone-*.patch` | `net/netfilter/0001-…` |
| `xanmod/net/netfilter/0001-netfilter-xt_FLOWOFFLOAD-*.patch` | `net/netfilter/0001-…` |
| `xanmod/net/tcp/bbr3/0001-tcp_bbr-v3-*.patch` | `net/tcp/bbr3/0001-…` |
| `xanmod/net/tcp/cloudflare/0001-tcp-collapse-*.patch` | `net/tcp/cloudflare/0001-…` |
