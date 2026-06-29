{
  lib,
  config,
  options,
  ...
}:
{
  options.lh.services.grafana = {
    enable = lib.mkEnableOption "Leon's Opinonated Grafana";
    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.traefik.enable;
        description = "Whether to integrate Grafana with Traefik";
      };
      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.grafana.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the Grafana Traefik router";
        example = "le";
      };
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "grafana.${config.networking.fqdn or "${config.networking.hostName}.local"}";
      defaultText = lib.literalExpression ''
        "grafana.''${config.networking.fqdn or "''${config.networking.hostName}.local"}"
      '';
      description = "The domain to access Grafana at";
      example = "grafana.example.com";
    };
  };

  # Build persistence definition only if impermanence (environment.persistence option) exists.
  config =
    let
      haveImpermanence = options ? environment && options.environment ? persistence;
      persistenceDef =
        if haveImpermanence then
          {
            environment.persistence."/persistent".directories = [
              {
                directory = "/var/lib/grafana";
                user = "grafana";
                group = "grafana";
                mode = "u,rwx,g=,o=";
              }
            ];
          }
        else
          { };
    in
    lib.mkIf config.lh.services.grafana.enable (
      persistenceDef
      // {
        services.grafana = {
          enable = true;
          openFirewall = false;
          settings = {
            server = {
              protocol = "socket";
              enforce_domain = true;
              inherit (config.lh.services.grafana) domain;
              enable_gzip = true;
            };
            security = {
              strict_transport_security_preload = true;
              strict_transport_security = true;
              disable_gravatar = true;
              cookie_secure = true;
              content_security_policy = true;
            };
            analytics = {
              reporting_enabled = false;
              feedback_links_enabled = false;
            };
          };
        };

        systemd = {
          services.grafana.serviceConfig = {
            ProtectSystem = lib.mkForce "strict";
            ProcSubset = "pid";
            SystemCallErrorNumber = "EPERM";
            ReadWritePaths = [
              "/var/lib/grafana"
              "/run/grafana"
            ];
            ReadOnlyPaths = [ "/nix/store" ];
            InaccessiblePaths = [
              "/home"
              "/root"
              "/srv"
            ];
            KeyringMode = "private";
            PrivateMounts = true;
            PrivateUsers = true;
            DevicePolicy = "closed";
            DeviceAllow = [ ];

            RootDirectory = "/var/run/jails/grafana";
            # RootDirectoryStartOnly = true;
            MountAPIVFS = true;

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
              "/var/lib/grafana:/var/lib/grafana"
              "/run/grafana:/run/grafana"
            ];
          };

          tmpfiles.rules = config.lh.lib.mkJailTmpfiles {
            serviceName = "grafana";
            user = "grafana";
            group = "grafana";
          };

          services.traefik = lib.mkIf config.lh.services.grafana.traefikIntegration.enable {
            serviceConfig = {
              BindReadOnlyPaths = [ "/run/grafana" ];
            };
          };
        };

        lh.services.traefik.dynamicConfig = lib.mkIf config.lh.services.grafana.traefikIntegration.enable {
          http.routers.grafana = {
            rule = "Host(`${config.lh.services.grafana.domain}`)";
            entryPoints = [ "websecure" ];
            service = "grafana";
            tls = {
              inherit (config.lh.services.grafana.traefikIntegration)
                certResolver
                ;
            };
          };
          http.services.grafana.loadBalancer.servers = [ { url = "unix+http:/run/grafana/grafana.sock"; } ];
        };

        users.users.traefik = lib.mkIf config.lh.services.grafana.traefikIntegration.enable {
          extraGroups = [ "grafana" ];
        };
      }
    );

}
