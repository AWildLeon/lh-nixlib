# Linux 6.18 LTS, server/router-tuned.
#
# Patches are vendored in ../kernel-patches/ — run update-patches.sh to refresh.
# Sources:
#   xanmod  https://gitlab.com/xanmod/linux-patches (linux-6.18.y-xanmod)
#
# ZFS (out-of-tree, no kernel patch needed):
#   boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux-lts-server-lhmod;
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
      # ── XanMod clearlinux (throughput-relevant only; skip ata/graphics) ──────
      { name = "xanmod-clearlinux-sched-accept-lifo";  patch = "${p}/xanmod/clearlinux/0001-sched-wait-Do-accept-in-LIFO-order-for-cache-efficie.patch"; }
      { name = "xanmod-clearlinux-firmware-stateless"; patch = "${p}/xanmod/clearlinux/0002-firmware-Enable-stateless-firmware-loading.patch"; }
      { name = "xanmod-clearlinux-rwsem-spin-faster";  patch = "${p}/xanmod/clearlinux/0003-locking-rwsem-spin-faster.patch"; }

      # ── XanMod net/netfilter ─────────────────────────────────────────────────
      { name = "xanmod-netfilter-nftables-fullcone"; patch = "${p}/xanmod/net/netfilter/0001-netfilter-Add-netfilter-nf_tables-fullcone-support.patch"; }
      { name = "xanmod-netfilter-xt-flowoffload";    patch = "${p}/xanmod/net/netfilter/0001-netfilter-add-xt_FLOWOFFLOAD-target.patch"; }

      # ── XanMod net/tcp ───────────────────────────────────────────────────────
      { name = "xanmod-tcp-bbr3";                       patch = "${p}/xanmod/net/tcp/bbr3/0001-tcp_bbr-v3-update-TCP-bbr-congestion-control-module-.patch"; }
      { name = "xanmod-tcp-cloudflare-collapse-sysctl"; patch = "${p}/xanmod/net/tcp/cloudflare/0001-tcp-Add-a-sysctl-to-skip-tcp-collapse-processing-whe.patch"; }
    ];

  structuredExtraConfig = with lib.kernel; {
    HZ = freeform "250";
    HZ_250 = yes;
    HZ_1000 = lib.mkForce no;
    HZ_300 = lib.mkForce no;

    PREEMPT_NONE = yes;
    PREEMPT_VOLUNTARY = lib.mkForce no;

    TRANSPARENT_HUGEPAGE = yes;
    TRANSPARENT_HUGEPAGE_ALWAYS = yes;
    TRANSPARENT_HUGEPAGE_MADVISE = lib.mkForce no;

    TCP_CONG_BBR = yes;
    DEFAULT_BBR = yes;
    DEFAULT_CUBIC = lib.mkForce no;

    IP_ADVANCED_ROUTER = yes;
    IP_MULTIPLE_TABLES = yes;
    IP_ROUTE_MULTIPATH = yes;
    IPV6_MULTIPLE_TABLES = yes;
    IPV6_SUBTREES = yes;
    NETFILTER_CONNTRACK_TIMESTAMP = yes;

    TRIM_UNUSED_KSYMS = lib.mkForce no;
  };
}
