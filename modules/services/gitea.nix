{
  lib,
  config,
  options,
  pkgs,
  ...
}:
{
  options.lh.services.gitea = {
    enable = lib.mkEnableOption "Leon's Opinionated Gitea Service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gitea;
      description = "The Gitea package to use";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.${config.networking.fqdn or "${config.networking.hostName}.local"}";
      defaultText = lib.literalExpression ''
        "git.''${config.networking.fqdn or "''${config.networking.hostName}.local"}"
      '';
      description = "The domain to access Gitea at";
      example = "git.example.com";
    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to disable user registration";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "The HTTP port for Gitea to listen on";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "The SSH port for Git operations";
    };

    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.traefik.enable;
        description = "Whether to integrate Gitea with Traefik";
      };

      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.gitea.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the Gitea Traefik router";
        example = "le";
      };

      middlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "A list of middlewares to apply to the Gitea Traefik router";
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional settings for Gitea configuration";
      example = {
        ui = {
          DEFAULT_THEME = "arc-green";
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
      };
    };

    mailer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable email functionality";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SMTP server host";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "SMTP server port";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SMTP username";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing SMTP password";
      };

      from = lib.mkOption {
        type = lib.types.str;
        default = "gitea@${config.lh.services.gitea.domain}";
        defaultText = lib.literalExpression ''
          "gitea@''${config.lh.services.gitea.domain}"
        '';
        description = "From address for emails";
      };
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Admin username";
    };

    adminEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@${config.lh.services.gitea.domain}";
      defaultText = lib.literalExpression ''
        "admin@''${config.lh.services.gitea.domain}"
      '';
      description = "Admin email address";
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to file containing admin password";
      example = "/var/lib/secrets/gitea-admin-password";
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
                directory = "/var/lib/gitea";
                user = "gitea";
                group = "gitea";
                mode = "u=rwx,g=rx,o=";
              }
            ];
          }
        else
          { };

      giteaSettings = {
        DEFAULT = {
          APP_NAME = "Gitea: Git with a cup of tea";
          RUN_MODE = "prod";
        };

        server = {
          DOMAIN = config.lh.services.gitea.domain;
          ROOT_URL = "https://${config.lh.services.gitea.domain}";
          DISABLE_SSH = false;
          SSH_PORT = config.lh.services.gitea.sshPort;
          SSH_LISTEN_PORT = config.lh.services.gitea.sshPort;
          START_SSH_SERVER = true;
          LFS_START_SERVER = true;
          OFFLINE_MODE = true;

          PROTOCOL = "http+unix";
          HTTP_ADDR = "/run/gitea/gitea.sock";
          UNIX_SOCKET_PERMISSION = "660";
        };

        repository = {
          DEFAULT_BRANCH = "main";
          DEFAULT_PRIVATE = "private";
        };

        ui = {
          DEFAULT_THEME = "gitea-auto";
        };

        service = {
          REGISTER_EMAIL_CONFIRM = false;
          ENABLE_NOTIFY_MAIL = config.lh.services.gitea.mailer.enable;
          DISABLE_REGISTRATION = config.lh.services.gitea.disableRegistration;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
          ENABLE_CAPTCHA = false;
          REQUIRE_SIGNIN_VIEW = false;
          DEFAULT_KEEP_EMAIL_PRIVATE = false;
          DEFAULT_ALLOW_CREATE_ORGANIZATION = true;
          DEFAULT_ENABLE_TIMETRACKING = true;
          NO_REPLY_ADDRESS = "noreply@${config.lh.services.gitea.domain}";
        };

        mailer = lib.mkIf config.lh.services.gitea.mailer.enable {
          ENABLED = true;
          HOST = config.lh.services.gitea.mailer.host;
          PORT = config.lh.services.gitea.mailer.port;
          USER = config.lh.services.gitea.mailer.user;
          FROM = config.lh.services.gitea.mailer.from;
          MAILER_TYPE = "smtp";
        };

        session = {
          COOKIE_SECURE = true;
        };

        openid = {
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = false;
        };

        log = {
          MODE = "console";
          LEVEL = "Info";
          ROOT_PATH = "/var/lib/gitea/log";
        };

        security = {
          INSTALL_LOCK = true;
        };
      }
      // config.lh.services.gitea.settings;

    in
    lib.mkIf config.lh.services.gitea.enable (
      persistenceDef
      // {
        assertions = [
          {
            assertion =
              config.lh.services.gitea.mailer.enable -> config.lh.services.gitea.mailer.passwordFile != null;
            message = "SMTP password file must be set when mailer is enabled";
          }
        ];

        services.gitea = {
          enable = true;
          inherit (config.lh.services.gitea) package;

          database = {
            type = "mysql";
            name = "gitea";
            user = "gitea";
            socket = "/run/mysqld/mysqld.sock";
          };

          lfs.enable = true;
          settings = giteaSettings;

          mailerPasswordFile = config.lh.services.gitea.mailer.passwordFile;
        };

        # Hardening with jailing system
        systemd = {
          services = {
            gitea = {
              serviceConfig = {
                ProtectSystem = lib.mkForce "strict";
                ProcSubset = "pid";
                SystemCallErrorNumber = "EPERM";
                ReadWritePaths = [
                  "/var/lib/gitea"
                  "/run/gitea"
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

                # RootDirectory = "/var/run/jails/gitea";
                # RootDirectoryStartOnly = true;
                MountAPIVFS = true;

                BindReadOnlyPaths = [
                  # "/bin"
                  # "/usr/bin"
                  # "/etc"
                  "/nix/store"
                  "/etc/ssl"
                  "/etc/resolv.conf"
                  "/etc/hosts"
                  "/run/current-system/sw/bin"
                  "/run/wrappers/bin"
                  "/etc/static/ssl"
                  "/run/mysqld"
                ];
                BindPaths = [
                  "/var/lib/gitea:/var/lib/gitea"
                  "/run/gitea:/run/gitea"
                ];
              };
              # Ensure gitea starts after mysql
              after = [ "mysql.service" ];
              wants = [ "mysql.service" ];
            };

            traefik = lib.mkIf config.lh.services.gitea.traefikIntegration.enable {
              after = [ "gitea.service" ];
              wants = [ "gitea.service" ];
              serviceConfig.BindReadOnlyPaths = [ "/run/gitea" ];
            };
          };

          tmpfiles.rules =
            (config.lh.lib.mkJailTmpfiles {
              serviceName = "gitea";
              user = "gitea";
              group = "gitea";
              dataPaths = [ "/var/lib/gitea" ];
            })
            ++ [ "d /run/gitea 0755 gitea gitea -" ];
        };

        lh.services = {

          # Traefik integration
          traefik.dynamicConfig = lib.mkIf config.lh.services.gitea.traefikIntegration.enable {
            http.routers.gitea = {
              rule = "Host(`${config.lh.services.gitea.domain}`)";
              entryPoints = [ "websecure" ];
              service = "gitea";
              middlewares = [ "securityheaders" ] ++ config.lh.services.gitea.traefikIntegration.middlewares;
              tls = {
                inherit (config.lh.services.gitea.traefikIntegration)
                  certResolver
                  ;
              };
            };
            http.services.gitea.loadBalancer.servers = [ { url = "unix+http:/run/gitea/gitea.sock"; } ];
          };

          # Database integration - automatically enable MariaDB
          db.mysql = {
            enable = lib.mkDefault true;
            ensureDatabases = [ "gitea" ];
            ensureUsers = [
              {
                name = "gitea";
                ensurePermissions = {
                  "gitea.*" = "ALL PRIVILEGES";
                };
              }
            ];
          };
        };

        users.users.traefik = lib.mkIf config.lh.services.gitea.traefikIntegration.enable {
          extraGroups = [ "gitea" ];
        };
      }
    );
}
