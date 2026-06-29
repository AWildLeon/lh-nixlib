{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lh.services.zammad;
  Zammad_serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = lib.mkForce "strict";
    ReadOnlyPaths = [ "/etc" ];
    DynamicUser = lib.mkForce false;
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    DeviceAllow = [
    ];
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    SystemCallArchitectures = "native";
    PrivateDevices = true;
    ProtectClock = true;
    RestrictNamespaces = "yes";
    ProtectKernelTunables = true;
    LockPersonality = true;
    ProtectControlGroups = true;
    RemoveIPC = true;
    ProtectHostname = true;
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

      # Allow capabilities needed
      "@chown"
      "ioperm"
      "iopl"
    ];
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    User = "zammad";
    Group = "zammad";
    ReadWritePaths = [
      "/var/lib/zammad/"
    ];
    BindReadOnlyPaths = [
      "/nix/store"
      "/etc/ssl"
      "/etc/resolv.conf"
      "/etc/hosts"
      "/run/current-system/sw/bin"
      "/run/wrappers/bin"
      "/etc/static/ssl"
      "/run/postgresql"
      "/run/agenix/zammad_secret_key_base"
    ];
    BindPaths = [
      "/var/lib/zammad/"
    ];
    MountAPIVFS = true;
    ProtectProc = lib.mkForce "invisible";
    ProcSubset = "pid";
    UMask = lib.mkForce "0077";
    RootDirectory = "/run/jails/zammad";
    PrivateUsers = true;
  };

in
{
  options.lh.services.zammad = {
    enable = lib.mkEnableOption "Zammad helpdesk system";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "The domain to access Zammad at";
      example = "support.example.com";
    };
    useNginx = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to configure Nginx for Zammad";
    };
    secretKeyBaseFile = lib.mkOption {
      type = lib.types.str;
      default = throw "You must specify a path to a file containing the secret_key_base for Zammad";
      description = "Path to a file containing the secret_key_base for Zammad";
      example = "/var/lib/zammad/.secret_key_base";
    };
  };

  config = lib.mkIf cfg.enable {
    lh.services.db.postgres.enable = true;
    lh.system.impermanence.persistentDirectories = [
      {
        directory = "/var/lib/zammad";
        mode = "0700";
        user = "zammad";
        group = "zammad";
      }
      {
        directory = "/var/lib/redis-zammad";
        mode = "0700";
        user = "redis-zammad";
        group = "redis-zammad";
      }
    ];

    services.zammad = {
      enable = true;
      nginx = {
        configure = cfg.useNginx;
        inherit (cfg) domain;
      };
      inherit (cfg) secretKeyBaseFile;
      redis.createLocally = true;
      database.createLocally = true;
    };
    services.redis.package = pkgs.valkey;
    systemd = {

      services = {
        zammad-web = {
          serviceConfig = Zammad_serviceConfig;

        };
        zammad-websocket = {
          serviceConfig = Zammad_serviceConfig;
        };
        zammad-worker = {
          serviceConfig = Zammad_serviceConfig;
        };

        redis-zammad = {
          serviceConfig = {
            RemoveIPC = true;
            RootDirectoryStartOnly = true;
            RootDirectory = "/run/jails/redis-zammad";
            ProtectProc = lib.mkForce "invisible";
            ProcSubset = "pid";
            ReadWritePaths = [
              "/var/lib/redis-zammad/"
            ];
            BindReadOnlyPaths = [
              "/nix/store"
              "/etc/ssl"
              "/etc/resolv.conf"
              "/etc/hosts"
              "/run/current-system/sw/bin"
              "/run/wrappers/bin"
              "/etc/static/ssl"
              "/run/postgresql"
            ];
            BindPaths = [
              "/var/lib/redis-zammad/"
              "/run/redis-zammad"
            ];
          };
        };
      };

      tmpfiles.rules =
        (config.lh.lib.mkJailTmpfiles {
          serviceName = "zammad";
          user = "zammad";
          group = "zammad";
        })
        ++ (config.lh.lib.mkJailTmpfiles {
          serviceName = "redis-zammad";
          user = "redis-zammad";
          group = "redis-zammad";
        });
    };
  };
}
