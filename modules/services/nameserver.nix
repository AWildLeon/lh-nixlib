{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.lh.services.nameserver;

in
{
  imports = [ ];

  options.lh.services.nameserver = {
    fqdn = lib.mkOption {
      type = lib.types.str;
      default = config.networking.fqdn or "${config.networking.hostName}.local";
      defaultText = lib.literalExpression ''
        config.networking.fqdn or "''${config.networking.hostName}.local"
      '';
      description = "The FQDN for the nameserver web interface";
      example = "dns.example.com";
    };
    enable = lib.mkEnableOption "Technitium DNS Server";

    traefikIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.lh.services.traefik.enable;
        description = "Whether to integrate nameserver with Traefik";
      };

      certResolver = lib.mkOption {
        type = lib.types.str;
        default =
          if config.lh.services.nameserver.traefikIntegration.enable then
            throw "You must set a certResolver if traefikIntegration is enabled"
          else
            "";
        description = "The certResolver to use for the nameserver Traefik router";
        example = "le";
      };

      middlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "A list of middlewares to apply to the nameserver Traefik router";
      };
    };

    acmeIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to integrate with ACME";
      };
      environmentFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/agenix/acme";
        description = "Paths to the credential files to write for ACME integration";
      };
      dnsProvider = lib.mkOption {
        type = lib.types.str;
        default = "rfc2136";
        description = "The DNS provider to use for ACME DNS-01 challenges";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Email address to use for ACME registration";
      };

    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.traefikIntegration.enable -> cfg.traefikIntegration.certResolver != "";
        message = "certResolver must be set when traefik integration is enabled for nameserver";
      }
      {
        assertion =
          cfg.acmeIntegration.enable
          -> (cfg.acmeIntegration.email != "" && cfg.acmeIntegration.environmentFile != "");
        message = "email and environmentFile must be set when ACME integration is enabled for nameserver";
      }
    ];

    services.technitium-dns-server = {
      enable = true;
      openFirewall = true;
      package = pkgs.technitium-dns-server;
    };

    users = {
      # Create user and group for the service
      users.technitium-dns-server = {
        group = "technitium-dns-server";
        isSystemUser = true;
        home = "/var/lib/nameserver";
        createHome = false; # StateDirectory will handle this
      };
      groups.technitium-dns-server = { };
    };

    # Traefik integration
    lh.services.traefik.dynamicConfig = lib.mkIf cfg.traefikIntegration.enable {
      http.routers.nameserver = {
        rule = "Host(`${cfg.fqdn}`)";
        entryPoints = [ "websecure" ];
        service = "nameserver";
        middlewares = [ "securityheaders" ] ++ cfg.traefikIntegration.middlewares;
        tls = { inherit (cfg.traefikIntegration) certResolver; };
      };
      http.services.nameserver.loadBalancer.servers = [ { url = "http://127.0.0.1:5380"; } ];
    };

    # ACME integration
    security.acme = lib.mkIf cfg.acmeIntegration.enable {
      acceptTerms = true;
      certs = {
        "${cfg.fqdn}" = {
          inherit (cfg.acmeIntegration) dnsProvider;
          inherit (cfg.acmeIntegration) environmentFile;
          inherit (cfg.acmeIntegration) email;
          postRun = ''
            PATH=${pkgs.openssl}/bin:${pkgs.coreutils}/bin:$PATH \
            openssl pkcs12 -export \
              -out "/var/lib/nameserver/cert.pfx" \
              -inkey "${config.security.acme.certs.${cfg.fqdn}.directory}/key.pem" \
              -in "${config.security.acme.certs.${cfg.fqdn}.directory}/fullchain.pem" \
              -passout pass: && \
            chown technitium-dns-server:technitium-dns-server "/var/lib/nameserver/cert.pfx"
          '';
        };
      };
    };

    # systemd-Overrides für die Unit
    systemd.services.technitium-dns-server.serviceConfig = {
      # Use /var/lib/nameserver instead of the default technitium-dns-server
      StateDirectory = lib.mkForce "nameserver";
      WorkingDirectory = lib.mkForce "/var/lib/nameserver";
      Environment = [
        "DNS_SERVER_LOG_FOLDER_PATH=/var/lib/nameserver/logs"
      ]
      ++ (
        if cfg.acmeIntegration.enable then
          [ "DNS_SERVER_WEB_SERVICE_TLS_CERTIFICATE_PATH=/var/lib/nameserver/cert.pfx" ]
        else
          [ ]
      );
      ExecStart = lib.mkForce "${pkgs.technitium-dns-server}/bin/technitium-dns-server /var/lib/nameserver";
      # Disable DynamicUser to avoid conflicts with existing directory
      DynamicUser = lib.mkForce false;
      # Set a specific user instead
      User = "technitium-dns-server";
      Group = "technitium-dns-server";

      BindPaths = lib.mkForce [ ];
    };

    # Persistenz via impermanence
    environment =
      lib.optionalAttrs
        (builtins.hasAttr "environment" config && builtins.hasAttr "persistence" config.environment)
        {
          persistence."/persistent" = {
            directories = [ "/var/lib/nameserver" ];
          };
        };
  };
}
