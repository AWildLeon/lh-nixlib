# Linux 6.18 LTS, router-tuned: TCP-AO, no graphical/desktop stack, low jitter.
#
# Patches are vendored in ../kernel-patches/ — run update-patches.sh to refresh.
# Sources:
#   xanmod  https://gitlab.com/xanmod/linux-patches (linux-6.18.y-xanmod)
{
  lib,
  linux_6_18,
}:

# Return `linux_6_18.override {…}` DIRECTLY so the result's `.override` is
# linux_6_18's own makeOverridable (real defaults for kernelPatches/features/
# randstructSeed). That is what makes the nixos kernel module's mandatory
# re-override (system/boot/kernel.nix: boot.kernelPackages.apply, which does
# `super.kernel.override (originalArgs: …)`) resolve to a hash-stable no-op —
# matching how nixpkgs' own cached kernels behave. Do NOT wrap in callPackage
# (that shadows `.override` with the wrapper lambda); see packages/part.nix.
linux_6_18.override {
  # We force off whole subsystems (DRM/SOUND/BT/MEDIA/STAGING); nixpkgs'
  # common-config.nix still forces answers for their children (SND_*,
  # MEDIA_*, ...), which become unreachable and are flagged as errors
  # without this.
  ignoreConfigErrors = true;

  structuredExtraConfig = with lib.kernel; {
    # ── TCP-AO (RFC 5925) + legacy MD5 (RFC 2385) for routing-protocol peers ──
    TCP_AO = yes;
    TCP_MD5SIG = yes;

    # ── routing ─────────────────────────────────────────────────────────────
    IP_ADVANCED_ROUTER = yes;
    IP_MULTIPLE_TABLES = yes;
    IP_ROUTE_MULTIPATH = yes;
    IPV6_MULTIPLE_TABLES = yes;
    IPV6_SUBTREES = yes;
    NF_CONNTRACK_TIMESTAMP = yes;

    TCP_CONG_BBR = yes;
    DEFAULT_BBR = yes;
    DEFAULT_CUBIC = lib.mkForce no;

    HZ = freeform "250";
    HZ_1000 = lib.mkForce no;
    HZ_250 = yes;
    HZ_300 = lib.mkForce no;
    # "Timer tick handling" is a Kconfig choice (HZ_PERIODIC/NO_HZ_IDLE/
    # NO_HZ_FULL). Force the other two members off, else the base config's
    # own member stays `y` and generate-config.pl aborts with "conflicting
    # answers" over the choice group.
    HZ_PERIODIC = lib.mkForce no;
    NO_HZ_IDLE = lib.mkForce yes;
    NO_HZ_FULL = lib.mkForce no;
    HIGH_RES_TIMERS = yes;

    PREEMPT = lib.mkForce yes;
    PREEMPT_NONE = lib.mkForce no;
    PREEMPT_VOLUNTARY = lib.mkForce no;
    PREEMPT_LAZY = lib.mkForce no;

    # THP compaction/khugepaged stalls buy a router nothing; drop it.
    TRANSPARENT_HUGEPAGE = lib.mkForce no;

    # Avoid P-state transition latency from on-demand/schedutil scaling.
    CPU_FREQ_DEFAULT_GOV_PERFORMANCE = yes;
    CPU_FREQ_DEFAULT_GOV_SCHEDUTIL = lib.mkForce no;
  };
}
