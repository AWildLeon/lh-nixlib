# Linux 6.18 LTS, desktop-tuned with zen-kernel and XanMod patches.
#
# Patch sources:
#   zen-sauce  — https://github.com/zen-kernel/zen-kernel/commits/6.18/zen-sauce
#                tip: 0c87fdcd (2026-02-14)
#   xanmod     — https://gitlab.com/xanmod/linux-patches/-/tree/master/linux-6.18.y-xanmod
#
# ZFS: out-of-tree OpenZFS is built automatically via linuxPackagesFor.
#   boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux-lts-desktop-lhmod;
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
      # ── zen-sauce patches ───────────────────────────────────────────────────
      {
        name = "zen-userns-clone-default";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/32af6da533c77f4310e477c3ee66646dd03cb4ad.patch";
          hash = "sha256-b3dn8gRqYG8TRJc5It5QJ1DodQk9O0vj935uQB70vbo=";
        };
      }
      {
        name = "zen-interactive-base";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/eb977217b0d0ff7df05ff1f8959cfc189e15d3a6.patch";
          hash = "sha256-IPc4x/R8Z+ijkrgVik3X62o0Km9y9u2FyVfq9GGi28E=";
        };
      }
      {
        name = "zen-ahci-disable-staggered-spinup";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/081953d744c06eb69253f10c95c08e61814e20eb.patch";
          hash = "sha256-/Buc8ViUsbWvTj5dbcSqENM6HPBDKIN4fpVLaqWJxGM=";
        };
      }
      {
        name = "zen-kswapd-early-stop";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/c3f4f675371b19a163eff5ccb46915a554421c31.patch";
          hash = "sha256-BaUpy+LERnsmte2yauI2utZXdghQzr6DLud72gvymI0=";
        };
      }
      {
        name = "zen-max-map-count";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/4ad8255385967917c640e6db77c0bc586ec6f637.patch";
          hash = "sha256-uUgP70VYugOUUStiyWAb/EYP+4Fd0eWCTRCtU87rTt0=";
        };
      }
      {
        name = "zen-kconfig-preempt-rt-no-expert";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/85a8f552737fc44b898a19ef15702f2177deed39.patch";
          hash = "sha256-HYymoOhml8dIpdizzAXcUyCFbxNIURaNEA1WyJHz2SI=";
        };
      }
      {
        name = "zen-mm-disable-watermark-boosting";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/a958950c2711ba2fe80e8bcb898bbafadd49b10d.patch";
          hash = "sha256-aVuJGQELO9yUYPzpvwvAnSmrQ32SklCEaQn2Pm0aBMY=";
        };
      }
      {
        name = "zen-mm-disable-swap-readahead";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/106748e12d5d93aa7ba61b7c914fcfcd0f460d2a.patch";
          hash = "sha256-4fnyFaZizVJ/WPYRnmypY7+GBmH43w0oqBe3pHBYbpU=";
        };
      }
      {
        name = "zen-interactive-disable-split-lock";
        patch = fetchpatch {
          url = "https://github.com/zen-kernel/zen-kernel/commit/0c87fdcd1f9f7f1a09e8928422160159b8966784.patch";
          hash = "sha256-PFL4Cna3bQFvQoNnwJbeYl5oWQkbKO/RRy0YvTykdeY=";
        };
      }

      # ── XanMod clearlinux patches ────────────────────────────────────────────
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
      {
        name = "xanmod-clearlinux-ata-before-graphics";
        patch = fetchpatch {
          url = "https://gitlab.com/xanmod/linux-patches/-/raw/master/linux-6.18.y-xanmod/clearlinux/0004-drivers-initialize-ata-before-graphics.patch";
          hash = "sha256-mWJT2DhwO3/2GkorNRl1crVLrIurh8Zf3+i1DfdysvE=";
        };
      }

      # ── XanMod net/netfilter patches ─────────────────────────────────────────
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

      # ── XanMod net/tcp patches ───────────────────────────────────────────────
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
    ZEN_INTERACTIVE = yes;

    HZ = freeform "1000";
    HZ_1000 = yes;
    HZ_300 = lib.mkForce no;
    HZ_250 = lib.mkForce no;

    PREEMPT_VOLUNTARY = yes;

    TRANSPARENT_HUGEPAGE = yes;
    TRANSPARENT_HUGEPAGE_MADVISE = yes;
    TRANSPARENT_HUGEPAGE_ALWAYS = lib.mkForce no;

    # BBR3 (updated by xanmod-tcp-bbr3 patch).
    TCP_CONG_BBR = yes;
    DEFAULT_BBR = yes;
    DEFAULT_CUBIC = lib.mkForce no;

    # Ensure out-of-tree modules (ZFS, DKMS) build correctly.
    TRIM_UNUSED_KSYMS = lib.mkForce no;
  };
}
