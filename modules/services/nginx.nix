{
  lib,
  config,
  lh,
  ...
}:

let
  cfg = config.lh.services.nginx;

in
{
  options.lh.services.nginx = {
    enable = lib.mkEnableOption "Nginx web server with recommended settings";
    disableJail = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable the Nginx jail. Not recommended for production use.";
    };
    enableAcme = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable ACME support for Nginx, Please lookup the Subscriber Agreement before enabling this";
    };
    fail2banBotsearch.enable = lib.mkEnableOption "the Fail2ban Nginx bot-search jail";
    ReadOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of additional paths to allow Nginx to read from.";
    };
    ReadWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of additional paths to allow Nginx to read and write to.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.acme.acceptTerms = cfg.enableAcme;

    services.nginx = {
      enable = true;
      # Use recommended settings
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      appendHttpConfig = ''
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        map $scheme $hsts_header {
            https   "max-age=31536000; includeSubdomains; preload";
        }
        add_header Strict-Transport-Security $hsts_header;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
      ''
      + lib.optionalString (config.lh.security.fail2ban.enable && cfg.fail2banBotsearch.enable) ''

        # The bundled nginx-botsearch filter reads the systemd journal.
        access_log /dev/stdout combined;
      '';
    };

    services.fail2ban.jails.nginx-botsearch =
      lib.mkIf (config.lh.security.fail2ban.enable && cfg.fail2banBotsearch.enable)
        {
          settings = {
            backend = "systemd";
            port = "http,https";
          };
        };

    networking.firewall.allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
    ];

    networking.firewall.allowedUDPPorts = [
      443 # HTTPS 3 (QUIC)
    ];

    systemd = lib.mkIf (!cfg.disableJail) {
      services.nginx = {
        wants = lib.optional config.services.mysql.enable "mysql.service";
        after = lib.optional config.services.mysql.enable "mysql.service";
        serviceConfig = {
          ProtectSystem = lib.mkForce "strict";
          SystemCallErrorNumber = "EPERM";
          ReadWritePaths = [
            "/run/nginx"
          ]
          ++ cfg.ReadWritePaths;
          ReadOnlyPaths = [ "/nix/store" ] ++ cfg.ReadOnlyPaths;
          InaccessiblePaths = [
            "/home"
            "/root"
            "/srv"
          ];

          RootDirectory = "/var/run/jails/nginx";
          RootDirectoryStartOnly = true;
          MountAPIVFS = true;

          BindReadOnlyPaths = [
            "/nix/store"
            "/etc/ssl"
            "/etc/resolv.conf"
            "/etc/hosts"
            "/run/current-system/sw/bin"
            "/run/wrappers/bin"
            "/etc/static/ssl"
            "/run/phpfpm:/run/phpfpm"
          ]
          ++ lib.optional cfg.enableAcme "/var/lib/acme"
          ++ lib.optional config.services.mysql.enable "/run/mysqld"
          ++ cfg.ReadOnlyPaths;
          BindPaths = [
            "/var/www:/var/www"
            "/run/nginx:/run/nginx"
          ]
          ++ cfg.ReadWritePaths;
        };
      };

      tmpfiles.rules =
        (lh.lib.modules.mkJailTmpfiles {
          serviceName = "nginx";
          user = "nginx";
          group = "nginx";
        })
        ++ [
          # Ensure /var/www exists for BindPaths
          "d /var/www 0755 nginx nginx -"
          "d /run/phpfpm 0777 root root -"
        ];
    };

    users.users.nginx.extraGroups = lib.mkIf config.services.mysql.enable [ "mysql" ];

  };
}
