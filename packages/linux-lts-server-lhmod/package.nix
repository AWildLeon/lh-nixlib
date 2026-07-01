# Linux 6.18 LTS, server/router-tuned with XanMod net patches.
#
# Profile: throughput over latency — low HZ, no preemption, BBR3, full
# netfilter feature set (fullcone NAT, flow offload) for routing use cases.
#
# ZFS: out-of-tree OpenZFS is built automatically via linuxPackagesFor.
#   boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux-lts-server-lhmod;
#   boot.supportedFilesystems.zfs = true;
{
  lib,
  linux_6_18,
  fetchpatch,
  maintainers ? [ ],
}:

linux_6_18.override {
  kernelPatches =
    linux_6_18.kernelPatches
    ++ [
      # ── XanMod clearlinux (throughput-relevant only) ──────────────────────────
      {
        name = "xanmod-clearlinux-sched-accept-lifo";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/clearlinux/0001-sched-wait-Do-accept-in-LIFO-order-for-cache-efficie.patch";
          hash = "sha256-xZWzn8U5yoijXDg6v3sJ+7vA+EAgyPCGekLix7TKCnE=";
        };
      }
      {
        name = "xanmod-clearlinux-firmware-stateless";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/clearlinux/0002-firmware-Enable-stateless-firmware-loading.patch";
          hash = "sha256-SjQ5wOLc9a/42o9aR9UZlhk+aWHrIP1DWv2RlM7QuAw=";
        };
      }
      {
        name = "xanmod-clearlinux-rwsem-spin-faster";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/clearlinux/0003-locking-rwsem-spin-faster.patch";
          hash = "sha256-4THgso5uVQQekOO2utzPTHjhM1NA5sGAs3Hb14iwYeE=";
        };
      }

      # ── XanMod net/netfilter ─────────────────────────────────────────────────
      {
        name = "xanmod-netfilter-nftables-fullcone";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/net/netfilter/0001-netfilter-Add-netfilter-nf_tables-fullcone-support.patch";
          hash = "sha256-4EGkJqX9fp0PWnIqrNIvWFnLoSVAxzIq7TBs1S59BZw=";
        };
      }
      {
        name = "xanmod-netfilter-xt-flowoffload";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/net/netfilter/0001-netfilter-add-xt_FLOWOFFLOAD-target.patch";
          hash = "sha256-87z+Rq5+bMAenZ2veKBT4cquUG9rm+sJknlVBkv1d6U=";
        };
      }

      # ── XanMod net/tcp ───────────────────────────────────────────────────────
      {
        name = "xanmod-tcp-bbr3";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/net/tcp/bbr3/0001-tcp_bbr-v3-update-TCP-bbr-congestion-control-module-.patch";
          hash = "sha256-3oCkx5d4yrDG6jJbkWz6KtoVk51mpzQ/eCimx19EH6g=";
        };
      }
      {
        name = "xanmod-tcp-cloudflare-collapse-sysctl";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/net/tcp/cloudflare/0001-tcp-Add-a-sysctl-to-skip-tcp-collapse-processing-whe.patch";
          hash = "sha256-ipWBD0RjG03ORyohvsRghT9X9I4fl0dyIuWSta6v5rs=";
        };
      }
    ];

  structuredExtraConfig = with lib.kernel; {
    # 250 Hz — lower tick rate trades latency for throughput.
    HZ = freeform "250";
    HZ_250 = yes;
    HZ_1000 = lib.mkForce no;
    HZ_300 = lib.mkForce no;

    # No preemption — maximizes throughput for server workloads.
    PREEMPT_NONE = yes;
    PREEMPT_VOLUNTARY = lib.mkForce no;

    # Always-on THP — servers benefit from reduced page-table overhead.
    TRANSPARENT_HUGEPAGE = yes;
    TRANSPARENT_HUGEPAGE_ALWAYS = yes;
    TRANSPARENT_HUGEPAGE_MADVISE = lib.mkForce no;

    # BBR3 (updated by xanmod-tcp-bbr3 patch).
    TCP_CONG_BBR = yes;
    DEFAULT_BBR = yes;
    DEFAULT_CUBIC = lib.mkForce no;

    # Routing / advanced networking.
    IP_ADVANCED_ROUTER = yes;
    IP_MULTIPLE_TABLES = yes;
    IP_ROUTE_MULTIPATH = yes;
    IPV6_MULTIPLE_TABLES = yes;
    IPV6_SUBTREES = yes;
    NETFILTER_CONNTRACK_TIMESTAMP = yes;

    # Ensure out-of-tree modules (ZFS, DKMS) build correctly.
    TRIM_UNUSED_KSYMS = lib.mkForce no;
  };
}
