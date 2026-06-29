{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lh.services.bootserver;

in
{
  options.lh.services.bootserver = {
    enable = mkEnableOption "PXE Boot Server with nginx and proxy DHCP";

    domain = mkOption {
      type = types.str;
      default = "bootserver.local";
      description = "Domain name for the boot server";
      example = "pxe.example.com";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/bootserver";
      description = "Directory to store boot server data";
    };

    proxyDhcp = {
      enable = mkEnableOption "Proxy DHCP server for PXE boot";

      interface = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Network interface to bind proxy DHCP to. If null, binds to all interfaces.";
        example = "eth0";
      };

      dhcpRange = mkOption {
        type = types.str;
        default = "10.0.0.254,proxy";
        description = "DHCP range for proxy mode";
      };
    };

    nfs = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable NFS server for persistent storage";
      };

      persistentDir = mkOption {
        type = types.path;
        default = "/var/lib/bootserver/persistent";
        description = "Directory to export for persistent client storage";
      };

      exports = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional NFS exports";
        example = [ "/srv/data *(rw,sync,no_subtree_check)" ];
      };
    };

    tftp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable TFTP server for serving boot files";
      };

      root = mkOption {
        type = types.path;
        default = "/var/lib/bootserver/www";
        description = "TFTP root directory";
      };

      interface = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Network interface to bind TFTP to. If null, binds to all interfaces.";
        example = "eth0";
      };
    };

    nginx = {
      enableSSL = mkOption {
        type = types.bool;
        default = false;
        description = "Enable SSL/TLS for the boot server";
      };

      extraLocations = mkOption {
        type = types.attrsOf types.attrs;
        default = { };
        description = "Additional nginx location blocks";
        example = {
          "/custom/" = {
            alias = "/custom/path/";
          };
        };
      };
    };

    php = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable PHP support for dynamic boot scripts";
      };

      maxChildren = mkOption {
        type = types.int;
        default = 5;
        description = "Maximum number of PHP-FPM children";
      };
    };

    defaultFiles = {
      bootScript = mkOption {
        type = types.lines;
        default = ''
          #!ipxe
          echo Default boot script - please configure your boot server
          shell
        '';
        description = "Default iPXE boot script content";
      };

      phpScript = mkOption {
        type = types.lines;
        default = ''
          <?php
          // Default boot.php - customize as needed
          header('Content-Type: text/plain');
          echo "#!ipxe\n";
          echo "echo Boot request from: " . $_GET['mac'] ?? 'unknown' . "\n";
          echo "shell\n";
          ?>
        '';
        description = "Default PHP boot script content";
      };
    };
  };

  config = mkIf cfg.enable {
    # Group service assignments into a single 'services' attrset
    services = {
      # Enable nginx directly without our module
      nginx.enable = true;

      # NFS Server configuration
      nfs.server = mkIf cfg.nfs.enable {
        enable = true;
        exports = ''
          ${cfg.nfs.persistentDir} *(rw,sync,no_subtree_check,no_root_squash)
        ''
        + optionalString (cfg.nfs.exports != [ ]) ("\n" + concatStringsSep "\n" cfg.nfs.exports);
      };

      # Enable required services for NFS
      rpcbind.enable = mkIf cfg.nfs.enable true;

      # TFTP Server configuration
      atftpd = mkIf cfg.tftp.enable {
        enable = true;
        inherit (cfg.tftp) root;
        extraOptions = [
          "--daemon"
          "--no-fork"
          "--user=bootserver"
          "--group=bootserver"
          "--verbose=7"
        ]
        ++ optionals (cfg.tftp.interface != null) [ "--bind-address=${cfg.tftp.interface}" ];
      };

      # Proxy DHCP configuration (dnsmasq)
      dnsmasq = mkIf cfg.proxyDhcp.enable {
        enable = true;
        settings = {
          # Don't provide DHCP or DNS services
          port = 0;
          dhcp-range = cfg.proxyDhcp.dhcpRange;

          # Bind to specific interface if specified
          interface = mkIf (cfg.proxyDhcp.interface != null) cfg.proxyDhcp.interface;

          # Enable TFTP server in dnsmasq if our TFTP is disabled
          enable-tftp = mkIf (!cfg.tftp.enable) true;
          tftp-root = mkIf (!cfg.tftp.enable) "${cfg.dataDir}/www";

          # PXE Boot configuration
          pxe-service = [
            ''tag:#ipxe,x86PC,"Boot from network",undionly.kpxe''
            ''tag:ipxe,x86PC,"Boot from network",http://${cfg.domain}/boot.ipxe''
            ''tag:#ipxe,x86-64_EFI,"Boot from network (UEFI)",snponly.efi''
            ''tag:ipxe,x86-64_EFI,"Boot from network (UEFI)",http://${cfg.domain}/boot.ipxe''
          ];

          # Enable PXE booting
          dhcp-no-override = true;

          # Set boot filename based on architecture
          dhcp-match = [
            "set:bios,option:client-arch,0"
            "set:efi32,option:client-arch,6"
            "set:efibc,option:client-arch,7"
            "set:efi64,option:client-arch,9"
            "set:ipxe,175"
          ];

          dhcp-boot = [
            "tag:bios,undionly.kpxe"
            "tag:efi32,snponly.efi"
            "tag:efibc,snponly.efi"
            "tag:efi64,snponly.efi"
          ];

          # Log DHCP requests
          log-dhcp = true;
        };
      };

      # Nginx virtual host (nested under nginx.virtualHosts)
      nginx = {
        virtualHosts = {
          "${cfg.domain}" = {
            default = true;
            root = "${cfg.dataDir}/www";

            locations = mkIf cfg.php.enable {
              "~ \\.php$" = {
                extraConfig = ''
                  fastcgi_pass unix:/run/phpfpm/bootserver.sock;
                  fastcgi_index index.php;
                  include ${pkgs.nginx}/conf/fastcgi_params;
                  fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                '';
              };
            };
          };
        };
      };

      # PHP-FPM pools
      phpfpm.pools.bootserver = mkIf cfg.php.enable {
        user = "bootserver";
        group = "bootserver";
        settings = {
          "listen" = "/run/phpfpm/bootserver.sock";
          "listen.owner" = "nginx";
          "listen.group" = "nginx";
          "pm" = "ondemand";
          "pm.max_children" = cfg.php.maxChildren;
          "pm.process_idle_timeout" = "60s";
          "pm.max_requests" = 500;
        };
      };
    };

    # Create bootserver user and group
    users = {
      users.bootserver = {
        isSystemUser = true;
        group = "bootserver";
        createHome = true;
      };

      groups.bootserver = { };
    };
    lh = {
      packages.ipxe.enable = true;

      # Add directories to impermanence if available
      system.impermanence.persistentDirectories = [
        {
          directory = cfg.dataDir;
          mode = "0755";
        }
      ]
      ++ optionals cfg.nfs.enable [
        cfg.nfs.persistentDir
        "/var/lib/nfs"
      ];
    };

    # Create directory structure and default files
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 bootserver bootserver"
      "d ${cfg.dataDir}/www 0755 bootserver bootserver"
      "d ${cfg.dataDir}/files 0755 bootserver bootserver"
    ]
    ++ optionals cfg.nfs.enable [ "d ${cfg.nfs.persistentDir} 0755 bootserver bootserver" ]
    ++ [
      # Create symlinks to iPXE files in www root for HTTP access
      "C+ ${cfg.dataDir}/www/undionly.kpxe - - - - ${pkgs.ipxe}/undionly.kpxe"
      "C+ ${cfg.dataDir}/www/snponly.efi - - - - ${pkgs.ipxe}/snponly.efi"
      "C+ ${cfg.dataDir}/www/undionly.kpxe.0 - - - - ${pkgs.ipxe}/undionly.kpxe"
      "C+ ${cfg.dataDir}/www/ipxe.efi - - - - ${pkgs.ipxe}/ipxe.efi"
      "C+ ${cfg.dataDir}/www/ipxe.usb - - - - ${pkgs.ipxe}/ipxe-efi.usb"
    ];
    networking = {

      # Firewall configuration
      firewall.allowedTCPPorts = [
        80
      ]
      ++ optionals cfg.nfs.enable [
        111
        2049
        4000
        4001
        4002
      ];

      firewall.allowedUDPPorts =
        mkIf cfg.proxyDhcp.enable [
          67
          69
        ]
        ++ optionals cfg.nfs.enable [
          111
          2049
          4000
          4001
          4002
        ];
    };
  };
}
