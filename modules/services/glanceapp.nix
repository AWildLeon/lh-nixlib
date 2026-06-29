{
  lib,
  config,
  lh,
  pkgs,
  inputs,
  ...
}:
let
  settingsFormat = pkgs.formats.yaml { };
in
{

  options.lh.services.glance = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable Glance (https://github.com/glanceapp/glance).
      '';
    };

    enableGlanceIcalEvents = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the Glance iCal Events plugin";
    };

    settings = lib.mkOption {
      inherit (settingsFormat) type;
      default = { };
      description = "Extra settings to pass to glance's configuration file";
    };

    assets-path = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to the glance assets, if you want to override the default";
      example = "/path/to/glance/assets";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "A list of environment files to include in the glance service";
    };

    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.traefik.enable;
        description = "Whether to integrate glance with Traefik";
      };

      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.glance.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the glance Traefik router";
        example = "le";
      };
      middlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "A list of middlewares to apply to the glance Traefik router";
      };
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "glance.${config.networking.fqdn or "${config.networking.hostName}.local"}";
      defaultText = lib.literalExpression ''
        "glance.''${config.networking.fqdn or "''${config.networking.hostName}.local"}"
      '';
      description = "The domain to access glance at";
      example = "glance.example.com";
    };
  };

  config = lib.mkIf config.lh.services.glance.enable (
    let
      cfg = config.lh.services.glance;
      fullSettings = {
        server = {
          assets-path = if cfg.assets-path != "" then cfg.assets-path else "/var/lib/glance/assets";
          socket-path = "/run/glance/webui.sock";
          socket-mode = "0660";
          proxied = true;
        };
      }
      // cfg.settings;
      settingsFile = settingsFormat.generate "glance.yaml" fullSettings;
      startPreScript = pkgs.writeShellScript "glance-start-pre" ''
        install -m 600 ${settingsFile} /run/glance/glance.yaml
        chown $USER /run/glance/glance.yaml
      '';
    in
    {
      assertions = [
        {
          assertion = !(cfg.settings ? server);
          message = "config.lh.services.glance.settings.server is managed internally by this module. Please use the provided options like 'assets-path' instead of setting server configuration directly.";
        }
      ];

      lh.services.traefik.dynamicConfig = lib.mkIf cfg.traefikIntegration.enable {
        http.routers.glance = {
          rule = "Host(`${cfg.domain}`)";
          entryPoints = [ "websecure" ];
          service = "glance";

          tls = {
            inherit (cfg.traefikIntegration) certResolver;
          };

          middlewares = [ "securityheaders" ] ++ cfg.traefikIntegration.middlewares;
        };
        http.services.glance.loadBalancer.servers = [ { url = "unix+http:/run/glance/webui.sock"; } ];
      };

      users = {
        users.traefik = lib.mkIf cfg.traefikIntegration.enable {
          extraGroups = [ "glance" ];
        };

        groups.glance = { };
        users.glance = {
          isSystemUser = true;
          group = "glance";
          home = "/var/lib/glance";
          createHome = false;
          description = "Glance User";
        };
      };

      services = {
        glance = {
          enable = true;
          package = inputs.lh-nixlib.packages.${pkgs.stdenv.hostPlatform.system}.glance;

          openFirewall = false;

          settings = fullSettings;
        };

        glance-ical-events = lib.mkIf cfg.enableGlanceIcalEvents {
          enable = true;
          host = "127.80.76.90";
          port = 8076;
          workers = 1;
        };
      };

      systemd = {
        services = {

          traefik = lib.mkIf cfg.traefikIntegration.enable {
            requires = [ "glance.service" ];
            after = [ "glance.service" ];
            serviceConfig = {
              BindReadOnlyPaths = [ "/run/glance/webui.sock" ];
            };
          };

          glance.serviceConfig = {
            User = "glance";
            Group = "glance";

            ExecStartPre = lib.mkForce "+${startPreScript}";

            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            PrivateDevices = true;
            ProtectSystem = "strict";

            EnvironmentFile = lib.mkIf (cfg.environmentFiles != [ ]) cfg.environmentFiles;

            SystemCallFilter = [
              "~@privileged"
              "~@setuid"
              "~@reboot"
              "~@module"
              "~@raw-io"
              "~@mount"
              "~@swap"
              "~@clock"
              "~@debug"
              "~@cpu-emulation"
              "~@obsolete"
              "~@resources"
            ];
            SystemCallErrorNumber = "EPERM";

            ProtectProc = "invisible";
            PrivateIPC = true;
            KeyringMode = "private";
            PrivateUsers = true;
            MemoryDenyWriteExecute = true;
            ProtectClock = true;

            CapabilityBoundingSet = lib.mkOverride 0 [ "" ];
            AmbientCapabilities = lib.mkOverride 0 [ "" ];

            ProcSubset = lib.mkForce "pid";

            SecureBits = "noroot-locked";
            RestrictSUIDSGID = true;

            RootDirectory = "/run/jails/glance";

            BindReadOnlyPaths = [
              "/nix/store"
              "/etc/ssl"
              "/etc/resolv.conf"
              "/etc/hosts"
              "/run/current-system/sw/bin"
              "/run/wrappers/bin"
              "/etc/static/ssl"
              "/etc/passwd"
            ];
            BindPaths = [
              "/var/lib/glance:/var/lib/glance"
              "/run/glance:/run/glance"
            ];

            ReadWritePaths = [
              "/var/lib/glance"
              "/run/glance"
            ];
            ReadOnlyPaths = [ "/nix/store" ];
          };

          "glance-ical-events".serviceConfig = lib.mkIf cfg.enableGlanceIcalEvents {
            RootDirectory = "/run/jails/glance-ical-events";
            BindReadOnlyPaths = [
              "/nix/store"
              "/etc/ssl"
              "/etc/resolv.conf"
              "/etc/hosts"
              "/run/current-system/sw/bin"
              "/run/wrappers/bin"
              "/etc/static/ssl"
              "/etc/passwd"
            ];

            ReadOnlyPaths = [ "/nix/store" ];
          };
        };

        tmpfiles.rules =
          lh.lib.modules.mkJailTmpfiles {
            serviceName = "glance";
            user = "glance";
            group = "glance";
          }
          ++ (
            if cfg.enableGlanceIcalEvents then
              lh.lib.modules.mkJailTmpfiles {
                serviceName = "glance-ical-events";
                user = "glance-ical-events";
                group = "glance-ical-events";
              }
            else
              [ ]
          );
      };
    }
  );
}
