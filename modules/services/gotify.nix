{
  lib,
  config,
  ...
}:
let
  cfg = config.lh.services.gotify;
in
{
  options.lh.services.gotify = {
    enable = lib.mkEnableOption "Gotify server";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "gotify.${config.networking.fqdn or "${config.networking.hostName}.local"}";
      defaultText = lib.literalExpression ''
        "gotify.''${config.networking.fqdn or "''${config.networking.hostName}.local"}"
      '';
      description = "The domain to access Gotify at";
      example = "gotify.example.com";
    };
    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.traefik.enable;
        description = "Whether to integrate Gotify with Traefik";
      };
      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.gotify.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the Gotify Traefik router";
        example = "le";
      };

      middlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "A list of middlewares to apply to the Gotify Traefik router";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.traefikIntegration.enable -> cfg.traefikIntegration.certResolver != "";
        message = "certResolver must be set when traefik integration is enabled for Gotify";
      }
    ];

    services.gotify = {
      enable = true;
      environment = {
        GOTIFY_SERVER_TRUSTEDPROXIES = "[127.0.0.1]";
        GOTIFY_REGISTRATION = "false";
        GOTIFY_SERVER_PORT = "51671";
        GOTIFY_SERVER_LISTENADDR = "127.51.67.1";
        GOTIFY_PASSSTRENGTH = "15";
        GOTIFY_DEFAULTUSER_NAME = "admin";
        GOTIFY_DEFAULTUSER_PASS = "admin";
      };
    };

    lh.services.traefik.dynamicConfig = lib.mkIf cfg.traefikIntegration.enable {
      http.routers.gotify = {
        rule = "Host(`${cfg.domain}`)";
        entryPoints = [ "websecure" ];
        service = "gotify";
        middlewares = [ "securityheaders" ] ++ cfg.traefikIntegration.middlewares;
        tls = { inherit (cfg.traefikIntegration) certResolver; };
      };
      http.services.gotify.loadBalancer.servers = [ { url = "http://127.51.67.1:51671"; } ];
    };
    users = {

      users.gotify = {
        isSystemUser = true;
        description = "Gotify user";
        home = "/var/lib/gotify-server";
        group = "gotify";
      };
      groups.gotify = { };
    };
    systemd = {

      services.gotify-server = {
        serviceConfig = {
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = lib.mkForce "strict";
          ReadOnlyPaths = [ "/etc" ];
          ReadWritePaths = [
            "/var/lib/gotify-server"
            "/var/lib/private/gotify-server"
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
            "/var/lib/gotify-server"
            "/var/lib/private/gotify-server"
          ];
          MountAPIVFS = true;
          User = "gotify";
          Group = "gotify";
          ProtectProc = lib.mkForce "invisible";
          ProcSubset = "pid";
          UMask = lib.mkForce "0077";
          RootDirectory = "/run/jails/gotify";
          # RootDirectoryStartOnly = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          RestrictNamespaces = "yes";
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
          IPAddressAllow = [
            "127.0.0.0/8"
            "::1"
          ];
          RestrictRealtime = true;
          ProtectKernelTunables = true;
          LockPersonality = true;
        };
      };

      tmpfiles.rules = config.lh.lib.mkJailTmpfiles {
        serviceName = "gotify";
        user = "gotify";
        group = "gotify";
        dataPaths = [
          "/var/lib/gotify-server"
          "/var/lib/private/gotify-server"
        ];
      };
    };

  };
}
