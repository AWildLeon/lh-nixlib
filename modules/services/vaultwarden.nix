{
  inputs-lhnixlib,
  pkgsUnstable,
  config,
  lh,
  lib,
  ...
}:
with lib;
let
  cfg = config.lh.services.vaultwarden;
  mkFail2banJail =
    {
      failregex,
      allports ? false,
    }:
    {
      filter = {
        INCLUDES.before = "common.conf";
        Definition = {
          inherit failregex;
          ignoreregex = "";
          journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
        };
      };
      settings = {
        backend = "systemd";
        port = "http,https";
        maxretry = 3;
        bantime = 14400;
        findtime = 14400;
      }
      // optionalAttrs allports { banaction = "%(banaction_allports)s"; };
    };
in
{
  options.lh.services.vaultwarden = {
    enable = mkOption {
      type = types.bool;
      description = "Enable Vaultwarden service.";
      default = false;
    };
    envFile = mkOption {
      type = types.nullOr types.str;
      description = "Path to the Vaultwarden environment file.";
      default = null;
    };
    allowSignups = mkOption {
      type = types.bool;
      description = "Allow user signups.";
      default = false;
    };
    smtp = {
      host = mkOption {
        type = types.nullOr types.str;
        description = "SMTP host for sending emails.";
        default = null;
      };
      port = mkOption {
        type = types.nullOr types.int;
        description = "SMTP port.";
        default = null;
      };
      ssl = mkOption {
        type = types.bool;
        description = "Use SSL for SMTP.";
        default = false;
      };
      from = mkOption {
        type = types.nullOr types.str;
        description = "Email address to send from.";
        default = null;
      };
      from_name = mkOption {
        type = types.nullOr types.str;
        description = "Name to send emails from.";
        default = null;
      };

    };

    database = {
      host = mkOption {
        type = types.str;
        description = "Database host for Vaultwarden.";
        default = "localhost";
      };
      port = mkOption {
        type = types.int;
        description = "Database port.";
        default = 3306;
      };
      database = mkOption {
        type = types.str;
        description = "Database name.";
        default = "vaultwarden";
      };
      user = mkOption {
        type = types.str;
        description = "Database user.";
        default = "vaultwarden";
      };
    };

    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.vaultwarden.enable;
        description = "Whether to integrate vault with Traefik";
      };

      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.vaultwarden.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the vault Traefik router";
        example = "le";
      };
      middlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "A list of middlewares to apply to the vault Traefik router";
      };
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "vault.${config.networking.fqdn or "${config.networking.hostName}.local"}";
      defaultText = lib.literalExpression ''
        "vault.''${config.networking.fqdn or "''${config.networking.hostName}.local"}"
      '';
      description = "The domain to access vault at";
      example = "vault.example.com";
    };

  };

  config = mkIf cfg.enable {
    lh.system.impermanence.persistentDirectories = [
      {
        directory = "/var/lib/vaultwarden";
        mode = "0700";
        user = "vaultwarden";
        group = "vaultwarden";
      }
    ];

    lh.services.db.mysql = {
      enable = lib.mkDefault true;
      ensureDatabases = [ "vaultwarden" ];
      ensureUsers = [
        {
          name = "vaultwarden";
          ensurePermissions = {
            "vaultwarden.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    systemd = {

      services.vaultwarden = {
        serviceConfig = {

          RootDirectory = "/run/jails/vaultwarden";

          BindReadOnlyPaths = [
            "/nix/store"
            "/etc/ssl"
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/current-system/sw/bin"
            "/run/wrappers/bin"
            "/etc/static/ssl"
            "/etc/passwd"
            "/run/mysqld"
          ]
          ++ lib.optional (cfg.envFile != null) cfg.envFile;
          BindPaths = [ "/var/lib/vaultwarden:/var/lib/vaultwarden" ];

          ReadWritePaths = [
            "/var/lib/vaultwarden"
            "/run/vaultwarden"
          ];
          ReadOnlyPaths = [ "/nix/store" ];

        };

        # Wait for MariaDB/Mysql
        after = [ "mysql.service" ];
        wants = [ "mysql.service" ];
      };

      tmpfiles.rules = lh.lib.modules.mkJailTmpfiles {
        serviceName = "vaultwarden";
        user = "vaultwarden";
        group = "vaultwarden";
      };
    };
    services = {

      vaultwarden = {
        package =
          pkgsUnstable.callPackage "${inputs-lhnixlib.nixpkgs-master}/pkgs/by-name/va/vaultwarden/package.nix"
            {
              dbBackend = "mysql";
            };
        enable = true;
        dbBackend = "mysql";
      }
      // (optionalAttrs (cfg.envFile != null) { environmentFile = cfg.envFile; })
      // {
        config = {
          SIGNUPS_ALLOWED = cfg.allowSignups;
          DOMAIN = "https://${cfg.domain}";
          ROCKET_ADDRESS = "127.0.8.222";
          ROCKET_PORT = "8222";
          ROCKET_LOG = "critical";

          DATABASE_URL = "mysql://${cfg.database.user}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.database}";

          ENABLE_WEBSOCKET = true;
        }
        // (optionalAttrs (cfg.smtp.host != null) {
          SMTP_HOST = cfg.smtp.host;
        })
        // (optionalAttrs (cfg.smtp.port != null) {
          SMTP_PORT = toString cfg.smtp.port;
        })
        // (optionalAttrs (cfg.smtp.from != null) {
          SMTP_FROM = cfg.smtp.from;
        })
        // (optionalAttrs (cfg.smtp.from_name != null) {
          SMTP_FROM_NAME = cfg.smtp.from_name;
        })
        // (optionalAttrs cfg.smtp.ssl { SMTP_SSL = cfg.smtp.ssl; });
        webVaultPackage = pkgsUnstable.vaultwarden.webvault;
      };
      fail2ban.jails = mkIf config.lh.security.fail2ban.enable {
        vaultwarden = mkFail2banJail {
          allports = true;
          failregex = ''
            ^.*?Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
          '';
        };
        vaultwarden-admin = mkFail2banJail {
          allports = true;
          failregex = ''
            ^.*Invalid admin token\. IP: <ADDR>.*$
          '';
        };
        vaultwarden-totp = mkFail2banJail {
          failregex = ''
            ^.*\[ERROR\] Invalid TOTP code! Server time: (.*) UTC IP: <ADDR>$
          '';
        };
      };
      traefik.dynamicConfigOptions.http = mkIf cfg.traefikIntegration.enable {
        services.vaultwarden = {
          loadBalancer.servers = [ { url = "http://127.0.8.222:8222"; } ];
        };
        routers.vaultwarden = {
          rule = "Host(`${cfg.domain}`)";
          service = "vaultwarden";
          tls.certResolver = cfg.traefikIntegration.certResolver;
          inherit (cfg.traefikIntegration) middlewares;
        };
      };
    };

  };

}
