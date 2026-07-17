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

    # ── strip graphical/desktop stack ──────────────────────────────────────
    # We only ever run under KVM, sometimes with a virtual VGA/QXL display for
    # console. Keep DRM but restrict it to the cheap virtual display drivers;
    # drop the real-hardware GPU drivers (i915/amdgpu/radeon/nouveau), which
    # are some of the single most expensive things in the whole tree to build.
    DRM = lib.mkForce yes;
    DRM_BOCHS = yes;
    DRM_CIRRUS_QEMU = yes;
    DRM_QXL = yes;
    DRM_VIRTIO_GPU = yes;
    DRM_I915 = lib.mkForce no;
    DRM_AMDGPU = lib.mkForce no;
    DRM_RADEON = lib.mkForce no;
    DRM_NOUVEAU = lib.mkForce no;
    DRM_VMWGFX = lib.mkForce no;
    SOUND = lib.mkForce no;
    BT = lib.mkForce no;
    MEDIA_SUPPORT = lib.mkForce no;
    STAGING = lib.mkForce no;

    # No wifi hardware ever exists under KVM/PCIe passthrough (Ethernet
    # only); this also drops every wifi driver (iwlwifi, ath9k, mt76, ...)
    # that nixpkgs' common-config enables as modules by default.
    CFG80211 = lib.mkForce no;

    # ── legacy/rare network protocols: attack surface, not just build time ──
    # These are exactly the kind of "reachable from a hostile packet but
    # never actually used" subsystems kernel-hardening guides (KSPP/CIS)
    # call out first. DECnet/IPX/AppleTalk-era cruft like ECONET, WAN_ROUTER
    # and DCCP have already been removed from mainline entirely.
    IP_SCTP = lib.mkForce no;
    RDS = lib.mkForce no;
    TIPC = lib.mkForce no;
    ATM = lib.mkForce no;
    HAMRADIO = lib.mkForce no; # gates AX25/NETROM/ROSE
    X25 = lib.mkForce no;
    ATALK = lib.mkForce no;
    NFC = lib.mkForce no;
    CAN = lib.mkForce no;

    # 32-bit compat syscall/ABI layer: real router userland is 64-bit only,
    # and the compat syscall table has been a recurring source of privilege-
    # escalation CVEs (it's a second, less-audited syscall entry surface).
    IA32_EMULATION = lib.mkForce no;
    X86_X32_ABI = lib.mkForce no;

    # Network filesystem clients: each one trusts a remote server and is
    # real attack surface if that server (or someone spoofing it) is
    # hostile; none of these are mounted from these routers.
    NFS_FS = lib.mkForce no;
    CIFS = lib.mkForce no;
    "9P_FS" = lib.mkForce no;
    AFS_FS = lib.mkForce no;
    CODA_FS = lib.mkForce no;
    ORANGEFS_FS = lib.mkForce no;

    # ── PCIe passthrough NICs: most-common vendors only ─────────────────────
    # drivers/net/ethernet/Kconfig gates every vendor directory behind its
    # own NET_VENDOR_* bool (all default y). Keep the vendors actually seen
    # in passthrough NICs (Intel, Realtek, Broadcom, Mellanox, Aquantia);
    # drop the other ~85, most of which are embedded-SoC or long-dead PCI/ISA
    # hardware that can never appear behind PCIe passthrough anyway.
    NET_VENDOR_3COM = lib.mkForce no;
    NET_VENDOR_8390 = lib.mkForce no;
    NET_VENDOR_ACTIONS = lib.mkForce no;
    NET_VENDOR_ADAPTEC = lib.mkForce no;
    NET_VENDOR_ADI = lib.mkForce no;
    NET_VENDOR_AGERE = lib.mkForce no;
    NET_VENDOR_AIROHA = lib.mkForce no;
    NET_VENDOR_ALACRITECH = lib.mkForce no;
    NET_VENDOR_ALLWINNER = lib.mkForce no;
    NET_VENDOR_ALTEON = lib.mkForce no;
    NET_VENDOR_AMAZON = lib.mkForce no;
    NET_VENDOR_AMD = lib.mkForce no;
    NET_VENDOR_APPLE = lib.mkForce no;
    NET_VENDOR_ARC = lib.mkForce no;
    NET_VENDOR_ASIX = lib.mkForce no;
    NET_VENDOR_ATHEROS = lib.mkForce no;
    NET_VENDOR_BROCADE = lib.mkForce no;
    NET_VENDOR_CADENCE = lib.mkForce no;
    NET_VENDOR_CAVIUM = lib.mkForce no;
    NET_VENDOR_CHELSIO = lib.mkForce no;
    NET_VENDOR_CIRRUS = lib.mkForce no;
    NET_VENDOR_CISCO = lib.mkForce no;
    NET_VENDOR_CORTINA = lib.mkForce no;
    NET_VENDOR_DAVICOM = lib.mkForce no;
    NET_VENDOR_DEC = lib.mkForce no;
    NET_VENDOR_DLINK = lib.mkForce no;
    NET_VENDOR_EMULEX = lib.mkForce no;
    NET_VENDOR_ENGLEDER = lib.mkForce no;
    NET_VENDOR_EZCHIP = lib.mkForce no;
    NET_VENDOR_FARADAY = lib.mkForce no;
    NET_VENDOR_FREESCALE = lib.mkForce no;
    NET_VENDOR_FUJITSU = lib.mkForce no;
    NET_VENDOR_FUNGIBLE = lib.mkForce no;
    NET_VENDOR_GOOGLE = lib.mkForce no;
    NET_VENDOR_HISILICON = lib.mkForce no;
    NET_VENDOR_HUAWEI = lib.mkForce no;
    NET_VENDOR_I825XX = lib.mkForce no;
    NET_VENDOR_IBM = lib.mkForce no;
    NET_VENDOR_LITEX = lib.mkForce no;
    NET_VENDOR_MARVELL = lib.mkForce no;
    NET_VENDOR_MEDIATEK = lib.mkForce no;
    NET_VENDOR_META = lib.mkForce no;
    NET_VENDOR_MICREL = lib.mkForce no;
    NET_VENDOR_MICROCHIP = lib.mkForce no;
    NET_VENDOR_MICROSEMI = lib.mkForce no;
    NET_VENDOR_MICROSOFT = lib.mkForce no;
    NET_VENDOR_MOXART = lib.mkForce no;
    NET_VENDOR_MYRI = lib.mkForce no;
    NET_VENDOR_NATSEMI = lib.mkForce no;
    NET_VENDOR_NETERION = lib.mkForce no;
    NET_VENDOR_NETRONOME = lib.mkForce no;
    NET_VENDOR_NI = lib.mkForce no;
    NET_VENDOR_NVIDIA = lib.mkForce no;
    NET_VENDOR_OKI = lib.mkForce no;
    NET_VENDOR_PACKET_ENGINES = lib.mkForce no;
    NET_VENDOR_PASEMI = lib.mkForce no;
    NET_VENDOR_PENSANDO = lib.mkForce no;
    NET_VENDOR_QLOGIC = lib.mkForce no;
    NET_VENDOR_QUALCOMM = lib.mkForce no;
    NET_VENDOR_RDC = lib.mkForce no;
    NET_VENDOR_RENESAS = lib.mkForce no;
    NET_VENDOR_ROCKER = lib.mkForce no;
    NET_VENDOR_SAMSUNG = lib.mkForce no;
    NET_VENDOR_SEEQ = lib.mkForce no;
    NET_VENDOR_SGI = lib.mkForce no;
    NET_VENDOR_SILAN = lib.mkForce no;
    NET_VENDOR_SIS = lib.mkForce no;
    NET_VENDOR_SMSC = lib.mkForce no;
    NET_VENDOR_SOCIONEXT = lib.mkForce no;
    NET_VENDOR_SOLARFLARE = lib.mkForce no;
    NET_VENDOR_SPACEMIT = lib.mkForce no;
    NET_VENDOR_STMICRO = lib.mkForce no;
    NET_VENDOR_SUN = lib.mkForce no;
    NET_VENDOR_SUNPLUS = lib.mkForce no;
    NET_VENDOR_SYNOPSYS = lib.mkForce no;
    NET_VENDOR_TEHUTI = lib.mkForce no;
    NET_VENDOR_TI = lib.mkForce no;
    NET_VENDOR_TOSHIBA = lib.mkForce no;
    NET_VENDOR_TUNDRA = lib.mkForce no;
    NET_VENDOR_VERTEXCOM = lib.mkForce no;
    NET_VENDOR_VIA = lib.mkForce no;
    NET_VENDOR_WANGXUN = lib.mkForce no;
    NET_VENDOR_WIZNET = lib.mkForce no;
    NET_VENDOR_XILINX = lib.mkForce no;
    NET_VENDOR_XIRCOM = lib.mkForce no;
    NET_VENDOR_XSCALE = lib.mkForce no;

    # ── storage: virtio-blk/virtio-scsi only, no real HBAs ─────────────────
    # ATA (libata) covers every SATA/PATA/AHCI chipset driver; NVMe and
    # Fusion MPT are real PCIe HBAs. None of these are reachable behind
    # virtio, and ATA/NVMe in particular are large driver families.
    ATA = lib.mkForce no;
    BLK_DEV_NVME = lib.mkForce no;
    FUSION = lib.mkForce no;

    # ── filesystems actually in use ────────────────────────────────────────
    BTRFS_FS = yes; # builtin, not a module
    EXT4_FS = yes;
    VFAT_FS = yes; # FAT32
    XFS_FS = lib.mkForce no;
    REISERFS_FS = lib.mkForce no;
    F2FS_FS = lib.mkForce no;
    NILFS2_FS = lib.mkForce no;
    JFS_FS = lib.mkForce no;
    # legacy NTFS_FS `select`s NTFS3_FS, so both must be off together or
    # Kconfig can never satisfy NTFS3_FS=n and the config generator hangs
    NTFS_FS = lib.mkForce no;
    NTFS3_FS = lib.mkForce no;
    HFS_FS = lib.mkForce no;
    HFSPLUS_FS = lib.mkForce no;
    GFS2_FS = lib.mkForce no;
    OCFS2_FS = lib.mkForce no;
    UBIFS_FS = lib.mkForce no;
    JFFS2_FS = lib.mkForce no;
    MINIX_FS = lib.mkForce no;
    SYSV_FS = lib.mkForce no;
    BFS_FS = lib.mkForce no;

    # ── USB: keyboard/mouse + USB ethernet only ─────────────────────────────
    # HID_GENERIC + USB_HID already cover plain USB keyboards/mice without
    # touching the ~100 individual HID vendor-quirk drivers (small each,
    # not worth the diff). Strip the subsystems with real build-cost payoff:
    # mass storage, the USB-serial adapter tree (~50 chip drivers), gadget/
    # device-mode, printer class, UAS.
    USB_STORAGE = lib.mkForce no;
    USB_UAS = lib.mkForce no;
    USB_SERIAL = lib.mkForce no;
    # On arm64 the Tegra EHCI host driver `select`s USB_GADGET, so both must
    # be off together — otherwise Kconfig can never satisfy USB_GADGET=n and
    # generate-config.pl aborts with "repeated question". Tegra is SoC silicon
    # that never exists under KVM/PCIe passthrough anyway.
    USB_EHCI_TEGRA = lib.mkForce no;
    USB_GADGET = lib.mkForce no;
    USB_PRINTER = lib.mkForce no;

    # USB ethernet: keep the handful of chip families actually seen in the
    # wild (Realtek RTL8152/8153, CDC-ECM/NCM standard class, ASIX, SMSC,
    # RNDIS), drop the long tail of legacy/niche vendor dongle drivers.
    USB_NET_DRIVERS = yes;
    USB_USBNET = yes;
    USB_RTL8152 = yes;
    USB_NET_CDCETHER = yes;
    USB_NET_CDC_NCM = yes;
    USB_NET_AX8817X = yes;
    USB_NET_AX88179_178A = yes;
    USB_NET_SMSC95XX = yes;
    USB_NET_RNDIS_HOST = yes;
    USB_CATC = lib.mkForce no;
    USB_KAWETH = lib.mkForce no;
    USB_PEGASUS = lib.mkForce no;
    USB_RTL8150 = lib.mkForce no;
    USB_LAN78XX = lib.mkForce no;
    USB_NET_CDC_EEM = lib.mkForce no;
    USB_NET_HUAWEI_CDC_NCM = lib.mkForce no;
    USB_NET_CDC_MBIM = lib.mkForce no;
    USB_NET_DM9601 = lib.mkForce no;
    USB_NET_SR9700 = lib.mkForce no;
    USB_NET_SR9800 = lib.mkForce no;
    USB_NET_SMSC75XX = lib.mkForce no;
    USB_NET_GL620A = lib.mkForce no;
    USB_NET_NET1080 = lib.mkForce no;
    USB_NET_PLUSB = lib.mkForce no;
    USB_NET_MCS7830 = lib.mkForce no;
    USB_NET_CDC_SUBSET_ENABLE = lib.mkForce no;
    USB_NET_ZAURUS = lib.mkForce no;
    USB_NET_CX82310_ETH = lib.mkForce no;
    USB_NET_KALMIA = lib.mkForce no;
    USB_NET_QMI_WWAN = lib.mkForce no;
    USB_HSO = lib.mkForce no;
    USB_NET_INT51X1 = lib.mkForce no;
    USB_CDC_PHONET = lib.mkForce no;
    USB_IPHETH = lib.mkForce no;
    USB_SIERRA_NET = lib.mkForce no;
    USB_NET_CH9200 = lib.mkForce no;
    USB_NET_AQC111 = lib.mkForce no;
    USB_RTL8153_ECM = lib.mkForce no;

    # ── other hypervisors / bare-metal-only cruft: we are always the KVM
    # guest, never the host, never Xen/Hyper-V/VMware/VirtualBox ─────────────
    KVM = lib.mkForce no; # never nest a hypervisor inside these VMs
    XEN = lib.mkForce no;
    HYPERV = lib.mkForce no;
    DRM_HYPERV = lib.mkForce no;
    VMWARE_BALLOON = lib.mkForce no;
    VMWARE_VMCI = lib.mkForce no;
    VMWARE_PVSCSI = lib.mkForce no;
    VMXNET3 = lib.mkForce no;
    VBOXGUEST = lib.mkForce no;
    VBOXSF_FS = lib.mkForce no;

    # ── dead physical-hardware classes ──────────────────────────────────────
    PARPORT = lib.mkForce no;
    BLK_DEV_FD = lib.mkForce no; # floppy
    INPUT_JOYSTICK = lib.mkForce no;
    INPUT_TABLET = lib.mkForce no;
    INPUT_TOUCHSCREEN = lib.mkForce no;

    # All keyboard/mouse input is USB (q35 + usb-tablet/usb-kbd); no VM ever
    # emulates PS/2, so drop the i8042 controller driver and its clients.
    SERIO_I8042 = lib.mkForce no;
    KEYBOARD_ATKBD = lib.mkForce no;
    MOUSE_PS2 = lib.mkForce no;

    TRIM_UNUSED_KSYMS = lib.mkForce no;

    # DEBUG_INFO gates DEBUG_INFO_BTF; disabling it skips the pahole BTF pass
    # over vmlinux, one of the single slowest steps in the whole build.
    DEBUG_INFO = lib.mkForce no;
  };
}
