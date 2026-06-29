{
  lib,
  config,
  lh,
  ...
}:
let
  cfg = config.lh.services.rustdesk-server;
in
{
  options.lh.services.rustdesk-server = {
    enable = lib.mkEnableOption "RustDesk self-hosted server (relay and signal)";
    endpoints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of domain names or IP addresses for the RustDesk server endpoints.";
      default = throw "You must specify at least one endpoint for the RustDesk server.";
      defaultText = lib.literalMD "Required — you must specify at least one endpoint.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.rustdesk-server = {
      enable = true;
      relay = {
        enable = true;
      };
      signal = {
        enable = true;
        relayHosts = cfg.endpoints;
      };
      openFirewall = true;
    };

    users.users.rustdesk = {
      isSystemUser = true;
      group = "rustdesk";
      home = "/var/lib/rustdesk";
      createHome = false;
    };

    lh.system.impermanence.persistentDirectories = [
      {
        directory = "/var/lib/rustdesk";
        mode = "0700";
        user = "rustdesk";
        group = "rustdesk";
      }
    ];

    users.groups.rustdesk = { };

    systemd = {
      services.rustdesk-relay = {
        serviceConfig = {
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = lib.mkForce "strict";
          ReadOnlyPaths = [ "/etc" ];
          DynamicUser = lib.mkForce false;
          User = "rustdesk";
          Group = "rustdesk";
          ReadWritePaths = [
            "/var/lib/rustdesk/"
          ];
          BindReadOnlyPaths = [
            "/nix/store"
            "/etc/ssl"
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/current-system/sw/bin"
            "/run/wrappers/bin"
            "/etc/static/ssl"
          ];
          BindPaths = [
            "/var/lib/rustdesk/"
          ];
          MountAPIVFS = true;
          ProtectProc = lib.mkForce "invisible";
          ProcSubset = "pid";
          UMask = lib.mkForce "0077";
          RootDirectory = "/run/jails/rustdesk";
          RootDirectoryStartOnly = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          PrivateUsers = true;
          SystemCallFilter = [
            "~@clock"
            "~@cpu-emulation"
            "~@debug"
            "~@mount"
            "~@obsolete"
            "~@privileged"
            "~@raw-io"
            "~@reboot"
            "~@resources"
            "~@swap"
          ];
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          PrivateDevices = true;
          ProtectClock = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectHostname = true;
          RestrictRealtime = true;
          ProtectKernelTunables = true;
          LockPersonality = true;
        };
      };
      services.rustdesk-signal = {
        serviceConfig = {
          NoNewPrivileges = true;
          PrivateTmp = true;
          DynamicUser = lib.mkForce false;
          User = "rustdesk";
          Group = "rustdesk";
          ProtectHome = true;
          ProtectSystem = lib.mkForce "strict";
          ReadOnlyPaths = [ "/etc" ];
          ReadWritePaths = [
            "/var/lib/rustdesk/"
          ];
          BindReadOnlyPaths = [
            "/nix/store"
            "/etc/ssl"
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/current-system/sw/bin"
            "/run/wrappers/bin"
            "/etc/static/ssl"
          ];
          BindPaths = [
            "/var/lib/rustdesk/"
          ];
          MountAPIVFS = true;
          ProtectProc = lib.mkForce "invisible";
          ProcSubset = "pid";
          UMask = lib.mkForce "0077";
          RootDirectory = "/run/jails/rustdesk";
          RootDirectoryStartOnly = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          PrivateUsers = true;
          SystemCallFilter = [
            "~@clock"
            "~@cpu-emulation"
            "~@debug"
            "~@mount"
            "~@obsolete"
            "~@privileged"
            "~@raw-io"
            "~@reboot"
            "~@resources"
            "~@swap"
          ];
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          PrivateDevices = true;
          ProtectClock = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectHostname = true;
          RestrictRealtime = true;
          ProtectKernelTunables = true;
          LockPersonality = true;
        };
      };

      tmpfiles.rules = lh.lib.modules.mkJailTmpfiles {
        serviceName = "rustdesk";
        user = "rustdesk";
        group = "rustdesk";
        dataPaths = [
          "/var/lib/rustdesk/"
        ];
      };
    };
  };
}
