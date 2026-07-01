# Linux 6.18 LTS, desktop-tuned.
#
# Patches are vendored in ../kernel-patches/ — run update-patches.sh to refresh.
# Sources:
#   zen-sauce  https://github.com/zen-kernel/zen-kernel/commits/6.18/zen-sauce
#   xanmod     https://gitlab.com/xanmod/linux-patches (linux-6.18.y-xanmod)
#
# ZFS (out-of-tree, no kernel patch needed):
#   boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux-lts-desktop-lhmod;
#   boot.supportedFilesystems.zfs = true;
{
  lib,
  linux_6_18,
}:

let
  p = ../kernel-patches;
in
linux_6_18.override {
  kernelPatches =
    linux_6_18.kernelPatches
    ++ [
      # ── zen-sauce ────────────────────────────────────────────────────────────
      { name = "zen-interactive-base";               patch = "${p}/zen-sauce/zen-interactive-base.patch"; }
      { name = "zen-ahci-disable-staggered-spinup";  patch = "${p}/zen-sauce/zen-ahci-disable-staggered-spinup.patch"; }
      { name = "zen-kswapd-early-stop";              patch = "${p}/zen-sauce/zen-kswapd-early-stop.patch"; }
      { name = "zen-max-map-count";                  patch = "${p}/zen-sauce/zen-max-map-count.patch"; }
      { name = "zen-kconfig-preempt-rt-no-expert";   patch = "${p}/zen-sauce/zen-kconfig-preempt-rt-no-expert.patch"; }
      { name = "zen-mm-disable-watermark-boosting";  patch = "${p}/zen-sauce/zen-mm-disable-watermark-boosting.patch"; }
      { name = "zen-mm-disable-swap-readahead";      patch = "${p}/zen-sauce/zen-mm-disable-swap-readahead.patch"; }
      { name = "zen-interactive-disable-split-lock"; patch = "${p}/zen-sauce/zen-interactive-disable-split-lock.patch"; }

      # ── XanMod clearlinux ────────────────────────────────────────────────────
      { name = "xanmod-clearlinux-sched-accept-lifo";   patch = "${p}/xanmod/clearlinux/0001-sched-wait-Do-accept-in-LIFO-order-for-cache-efficie.patch"; }
      { name = "xanmod-clearlinux-firmware-stateless";  patch = "${p}/xanmod/clearlinux/0002-firmware-Enable-stateless-firmware-loading.patch"; }
      { name = "xanmod-clearlinux-rwsem-spin-faster";   patch = "${p}/xanmod/clearlinux/0003-locking-rwsem-spin-faster.patch"; }
      { name = "xanmod-clearlinux-ata-before-graphics"; patch = "${p}/xanmod/clearlinux/0004-drivers-initialize-ata-before-graphics.patch"; }

      # ── XanMod net/netfilter ─────────────────────────────────────────────────
      { name = "xanmod-netfilter-nftables-fullcone"; patch = "${p}/xanmod/net/netfilter/0001-netfilter-Add-netfilter-nf_tables-fullcone-support.patch"; }
      { name = "xanmod-netfilter-xt-flowoffload";    patch = "${p}/xanmod/net/netfilter/0001-netfilter-add-xt_FLOWOFFLOAD-target.patch"; }

      # ── XanMod net/tcp ───────────────────────────────────────────────────────
      { name = "xanmod-tcp-bbr3";                      patch = "${p}/xanmod/net/tcp/bbr3/0001-tcp_bbr-v3-update-TCP-bbr-congestion-control-module-.patch"; }
      { name = "xanmod-tcp-cloudflare-collapse-sysctl"; patch = "${p}/xanmod/net/tcp/cloudflare/0001-tcp-Add-a-sysctl-to-skip-tcp-collapse-processing-whe.patch"; }
    ];

  structuredExtraConfig = with lib.kernel; {
    ZEN_INTERACTIVE = yes;

    HZ = freeform "1000";
    HZ_1000 = yes;
    HZ_300 = lib.mkForce no;
    HZ_250 = lib.mkForce no;

    PREEMPT_VOLUNTARY = yes;

    TRANSPARENT_HUGEPAGE = yes;
    TRANSPARENT_HUGEPAGE_MADVISE = yes;
    TRANSPARENT_HUGEPAGE_ALWAYS = lib.mkForce no;

    TCP_CONG_BBR = yes;
    DEFAULT_BBR = yes;
    DEFAULT_CUBIC = lib.mkForce no;

    TRIM_UNUSED_KSYMS = lib.mkForce no;
  };
}
