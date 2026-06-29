{
  lib,
  config,
  options,
  pkgsUnstable,
  ...
}:
let
  cfg = config.lh.services.uptime-kuma;
in
{
  options.lh.services.uptime-kuma = {
    enable = lib.mkEnableOption "uptime-kuma server";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma.${config.networking.fqdn or "${config.networking.hostName}.local"}";
      defaultText = lib.literalExpression ''
        "uptime-kuma.''${config.networking.fqdn or "''${config.networking.hostName}.local"}"
      '';
      description = "The domain to access uptime-kuma at";
      example = "uptime-kuma.example.com";
    };
    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.traefik.enable;
        description = "Whether to integrate uptime-kuma with Traefik";
      };
      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.uptime-kuma.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the uptime-kuma Traefik router";
        example = "le";
      };

      middlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "A list of middlewares to apply to the uptime-kuma Traefik router";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.traefikIntegration.enable -> cfg.traefikIntegration.certResolver != "";
        message = "certResolver must be set when traefik integration is enabled for uptime-kuma";
      }
    ];

    services.uptime-kuma = {
      enable = true;
      package = pkgsUnstable.uptime-kuma;
      settings = {
        HOST = "127.23.12.7";
        PORT = "38412";
        # UPTIME_KUMA_DB_TYPE = "mariadb";
        # UPTIME_KUMA_DB_HOSTNAME = "127.0.0.1";
        # UPTIME_KUMA_DB_NAME = "uptimekuma";
        # UPTIME_KUMA_DB_USERNAME = "uptime-kuma";
        # UPTIME_KUMA_DB_PASSWORD = "dummy_password";
      };
    };

    # lh.services.db.mysql = {
    #   enable = true;
    #   ensureDatabases = [ "uptimekuma" ];
    #   ensureUsers = [{
    #     name = "uptime-kuma";
    #     ensurePermissions = { "uptimekuma.*" = "ALL PRIVILEGES"; };
    #   }];
    # };

    lh.services.traefik.dynamicConfig = lib.mkIf cfg.traefikIntegration.enable {
      http.routers.uptime-kuma = {
        rule = "Host(`${cfg.domain}`)";
        entryPoints = [ "websecure" ];
        service = "uptime-kuma";
        middlewares = [ "securityheaders" ] ++ cfg.traefikIntegration.middlewares;
        tls = { inherit (cfg.traefikIntegration) certResolver; };
      };
      http.services.uptime-kuma.loadBalancer.servers = [ { url = "http://127.23.12.7:38412"; } ];
    };
    users = {

      users.uptime-kuma = {
        isSystemUser = true;
        group = "uptime-kuma";
        description = "Uptime-Kuma user";
        home = "/var/lib/private/uptime-kuma";
      };

      groups.uptime-kuma = { };
    };
    systemd = {

      services.uptime-kuma = {
        serviceConfig = {
          ReadWritePaths = [
            "/var/lib/uptime-kuma"
            "/var/lib/private/uptime-kuma"
          ];
          ProtectSystem = lib.mkForce "strict";
          BindReadOnlyPaths = [
            "/etc/passwd"
            "/nix/store"
            "/etc/ssl"
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/current-system/sw/bin"
            "/run/wrappers/bin"
            "/etc/static/ssl"
            "/bin"
            "/usr/bin"
            # "/run/mysqld/mysqld.sock"
          ];

          BindPaths = [
            "/var/lib/uptime-kuma"
            "/var/lib/private/uptime-kuma"
          ];
          MountAPIVFS = true;

          user = "uptime-kuma";
          group = "uptime-kuma";
          ProtectProc = lib.mkForce "invisible";
          ProcSubset = "pid";
          UMask = lib.mkForce "0077";

          PrivateUsers = true;

          SystemCallFilter = [
            "~@cpu-emulation"
            "~@debug"
            "~@mount"
            "~@obsolete"
            "~@swap"
            "~@clock"
            "~@reboot"
            "~@module"
            "~@resources"
          ];

          # AmbientCapabilities = lib.mkForce "CAP_NET_RAW";
          # CapabilityBoundingSet = lib.mkForce "CAP_NET_RAW";

          RootDirectory = "/run/jails/uptime-kuma";
          # RootDirectoryStartOnly = true;
        };
      };

      tmpfiles.rules = config.lh.lib.mkJailTmpfiles {
        serviceName = "uptime-kuma";
        user = "uptime-kuma";
        group = "uptime-kuma";
        dataPaths = [
          "/var/lib/uptime-kuma"
          "/var/lib/private/uptime-kuma"
        ];
      };
    };
  };
}
