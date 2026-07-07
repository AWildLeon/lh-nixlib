{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.lh.services.accel-ppp;
  configFile = pkgs.writeText "accel-ppp.conf" cfg.configText;
in
{
  options.lh.services.accel-ppp = {
    enable = lib.mkEnableOption "accel-ppp tunnel server (PPPoE/PPTP/L2TP/SSTP/IPoE)";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.lh-nixlib.packages.${pkgs.stdenv.hostPlatform.system}.accel-ppp;
      defaultText = lib.literalExpression "inputs.lh-nixlib.packages.<system>.accel-ppp";
      description = "The accel-ppp package to use.";
    };

    configText = lib.mkOption {
      type = lib.types.lines;
      default = throw "You must set lh.services.accel-ppp.configText (accel-ppp.conf contents).";
      defaultText = lib.literalMD "Required — you must provide the accel-ppp.conf contents.";
      description = ''
        Raw contents of accel-ppp.conf. accel-ppp's config format (custom
        INI-like, with bare module names and repeated keys) doesn't map
        cleanly onto a Nix settings attrset, so it's passed through as-is.
        See https://accel-ppp.org/doc/config for the full reference.
      '';
      example = ''
        [modules]
        log_syslog
        pppoe
        auth_pap
        auth_chap_md5

        [core]
        log-error=/dev/stderr
        thread-count=4

        [pppoe]
        interface=eth0
        ac-name=accel-ppp

        [client-ip-range]
        192.168.100.0/24
      '';
    };

    openFirewall = {
      tcp = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "TCP ports to open in the firewall (e.g. 1723 for PPTP, 443 for SSTP).";
      };
      udp = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "UDP ports to open in the firewall (e.g. 1701 for L2TP).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.accel-ppp = {
      isSystemUser = true;
      group = "accel-ppp";
      description = "accel-ppp service user";
    };
    users.groups.accel-ppp = { };

    # accel-pppd talks to the kernel over /dev/ppp (PPP channel/unit ioctls)
    # and /dev/net/tun (IPoE, tun-backed interfaces); default udev perms
    # restrict both to root, so grant the service group access instead of
    # running as root.
    services.udev.extraRules = ''
      KERNEL=="ppp", GROUP="accel-ppp", MODE="0660"
      KERNEL=="tun", SUBSYSTEM=="misc", GROUP="accel-ppp", MODE="0660"
    '';

    networking.firewall = {
      allowedTCPPorts = cfg.openFirewall.tcp;
      allowedUDPPorts = cfg.openFirewall.udp;
    };

    systemd.services.accel-ppp = {
      description = "accel-ppp tunnel server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/accel-pppd -c ${configFile} -p /run/accel-ppp/accel-ppp.pid";
        Restart = "on-failure";
        RestartSec = 2;

        User = "accel-ppp";
        Group = "accel-ppp";

        RuntimeDirectory = "accel-ppp";
        StateDirectory = "accel-ppp";
        LogsDirectory = "accel-ppp";

        # PPPoE discovery (AF_PACKET), IP/route/link config and the ppp
        # kernel module (AF_NETLINK) all need real net-admin/net-raw access;
        # this can't be sandboxed away like a typical userspace service.
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
        ];
        DeviceAllow = [
          "/dev/ppp rw"
          "/dev/net/tun rw"
        ];
        DevicePolicy = "closed";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_PACKET"
          "AF_NETLINK"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectHostname = true;
        ProtectClock = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        UMask = "0077";

        SystemCallFilter = [
          "~@clock"
          "~@cpu-emulation"
          "~@debug"
          "~@mount"
          "~@obsolete"
          "~@reboot"
          "~@resources"
          "~@swap"
        ];
      };
    };

    lh.system.impermanence.persistentDirectories = [
      {
        directory = "/var/lib/accel-ppp";
        mode = "0750";
        user = "accel-ppp";
        group = "accel-ppp";
      }
      {
        directory = "/var/log/accel-ppp";
        mode = "0750";
        user = "accel-ppp";
        group = "accel-ppp";
      }
    ];
  };
}
