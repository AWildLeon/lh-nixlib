#!/usr/bin/env bash
# Download individual kernel patch files from upstream sources.
# Run from repo root or this directory — paths are relative to this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── helpers ──────────────────────────────────────────────────────────────────

fetch() {
  local dest="$1" url="$2"
  local dir; dir="$(dirname "$dest")"
  mkdir -p "$dir"
  echo "  → $dest"
  curl -fsSL "$url" -o "$dest"
}

section() { echo; echo "── $* ──"; }

# ── zen-sauce (GitHub — stable commit SHAs, never changes) ──────────────────
# Source: https://github.com/zen-kernel/zen-kernel/commits/6.18/zen-sauce
# Tip commit: 0c87fdcd1f9f7f1a09e8928422160159b8966784 (2026-02-14)
# To update: find newer commits on 6.18/zen-sauce and add their SHAs below.

ZEN_BASE="https://github.com/zen-kernel/zen-kernel/commit"
ZEN_RAW="https://raw.githubusercontent.com/zen-kernel/zen-kernel/6.18/main"

section "zen-sauce license + patches"
fetch zen-sauce/COPYING "$ZEN_RAW/COPYING"
fetch zen-sauce/zen-userns-clone-default.patch        "$ZEN_BASE/32af6da533c77f4310e477c3ee66646dd03cb4ad.patch"
fetch zen-sauce/zen-interactive-base.patch             "$ZEN_BASE/eb977217b0d0ff7df05ff1f8959cfc189e15d3a6.patch"
fetch zen-sauce/zen-ahci-disable-staggered-spinup.patch "$ZEN_BASE/081953d744c06eb69253f10c95c08e61814e20eb.patch"
fetch zen-sauce/zen-kswapd-early-stop.patch            "$ZEN_BASE/c3f4f675371b19a163eff5ccb46915a554421c31.patch"
fetch zen-sauce/zen-max-map-count.patch                "$ZEN_BASE/4ad8255385967917c640e6db77c0bc586ec6f637.patch"
fetch zen-sauce/zen-kconfig-preempt-rt-no-expert.patch "$ZEN_BASE/85a8f552737fc44b898a19ef15702f2177deed39.patch"
fetch zen-sauce/zen-mm-disable-watermark-boosting.patch "$ZEN_BASE/a958950c2711ba2fe80e8bcb898bbafadd49b10d.patch"
fetch zen-sauce/zen-mm-disable-swap-readahead.patch    "$ZEN_BASE/106748e12d5d93aa7ba61b7c914fcfcd0f460d2a.patch"
fetch zen-sauce/zen-interactive-disable-split-lock.patch "$ZEN_BASE/0c87fdcd1f9f7f1a09e8928422160159b8966784.patch"

# ── XanMod (GitLab — pinned to a commit SHA for reproducibility) ─────────────
# Source: https://gitlab.com/xanmod/linux-patches
# To update: get the new master SHA with:
#   curl -s "https://gitlab.com/api/v4/projects/xanmod%2Flinux-patches/repository/commits?ref_name=master&per_page=1" | jq -r '.[0].id'
# Then replace XANMOD_COMMIT below and re-run this script.

XANMOD_COMMIT="16b5ed95569b7b66889cf34ee233a83aac9df307"
XANMOD_RAW="https://gitlab.com/xanmod/linux-patches/-/raw/${XANMOD_COMMIT}"
XANMOD_BASE="${XANMOD_RAW}/linux-6.18.y-xanmod"

section "XanMod license + clearlinux patches  (commit ${XANMOD_COMMIT:0:12})"
fetch xanmod/LICENSE "$XANMOD_RAW/LICENSE"
fetch xanmod/clearlinux/0001-sched-wait-Do-accept-in-LIFO-order-for-cache-efficie.patch \
  "$XANMOD_BASE/clearlinux/0001-sched-wait-Do-accept-in-LIFO-order-for-cache-efficie.patch"
fetch xanmod/clearlinux/0002-firmware-Enable-stateless-firmware-loading.patch \
  "$XANMOD_BASE/clearlinux/0002-firmware-Enable-stateless-firmware-loading.patch"
fetch xanmod/clearlinux/0003-locking-rwsem-spin-faster.patch \
  "$XANMOD_BASE/clearlinux/0003-locking-rwsem-spin-faster.patch"
fetch xanmod/clearlinux/0004-drivers-initialize-ata-before-graphics.patch \
  "$XANMOD_BASE/clearlinux/0004-drivers-initialize-ata-before-graphics.patch"

section "XanMod net/netfilter patches"
fetch xanmod/net/netfilter/0001-netfilter-Add-netfilter-nf_tables-fullcone-support.patch \
  "$XANMOD_BASE/net/netfilter/0001-netfilter-Add-netfilter-nf_tables-fullcone-support.patch"
fetch xanmod/net/netfilter/0001-netfilter-add-xt_FLOWOFFLOAD-target.patch \
  "$XANMOD_BASE/net/netfilter/0001-netfilter-add-xt_FLOWOFFLOAD-target.patch"

section "XanMod net/tcp patches"
fetch xanmod/net/tcp/bbr3/0001-tcp_bbr-v3-update-TCP-bbr-congestion-control-module-.patch \
  "$XANMOD_BASE/net/tcp/bbr3/0001-tcp_bbr-v3-update-TCP-bbr-congestion-control-module-.patch"
fetch xanmod/net/tcp/cloudflare/0001-tcp-Add-a-sysctl-to-skip-tcp-collapse-processing-whe.patch \
  "$XANMOD_BASE/net/tcp/cloudflare/0001-tcp-Add-a-sysctl-to-skip-tcp-collapse-processing-whe.patch"

echo
echo "Done. Commit changed files. No hash updates needed — patches referenced by path."
