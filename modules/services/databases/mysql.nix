{
  lib,
  config,
  options,
  pkgs,
  ...
}:
{
  options.lh.services.db.mysql = {
    enable = lib.mkEnableOption "Leon's Opinonated MySQL Database Service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mariadb;
      description = "The MySQL package to use";
    };
    ensureDatabases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of database names to ensure exist";
    };
    ensureUsers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the user";
            };
            ensurePermissions = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Permissions to ensure for the user";
            };
          };
        }
      );
      default = [ ];
      description = "List of users to ensure exist with their permissions";
    };
  };

  # Build persistence definition only if impermanence (environment.persistence option) exists.
  config = lib.mkIf config.lh.services.db.mysql.enable (
    let
      haveImpermanence = options ? environment && options.environment ? persistence;
      persistenceDef =
        if haveImpermanence then
          {
            environment.persistence."/persistent".directories = [
              {
                directory = "/var/lib/mysql";
                user = "mysql";
                group = "mysql";
                mode = "u=rwx,g=,o=";
              }
            ];
          }
        else
          { };
    in
    persistenceDef
    // {
      services.mysql = {
        enable = true;
        inherit (config.lh.services.db.mysql) package;
        inherit (config.lh.services.db.mysql) ensureDatabases;
        inherit (config.lh.services.db.mysql) ensureUsers;

        ## Security settings
        settings = {
          mysqld = {
            bind-address = "";
            skip-networking = true;
            skip-name-resolve = true;
            local-infile = false;
            secure-file-priv = "/var/lib/mysql-files";
          };
        };
      };

      # Create necessary directories
      systemd.tmpfiles.rules = [
        "d /var/log/mysql 0750 mysql mysql -"
        "d /var/lib/mysql-files 0750 mysql mysql -"
      ]
      ++ config.lh.lib.mkJailTmpfiles {
        serviceName = "mysqld";
        user = "mysql";
        group = "mysql";
        dataPaths = [
          "/var/lib/mysql"
          "/var/log/mysql"
          "/var/lib/mysql-files"
        ];
      };

      # Comprehensive systemd hardening
      systemd.services.mysql = {
        serviceConfig = {
          # File system protection
          ProtectSystem = lib.mkForce "strict";
          ReadWritePaths = [
            "/var/lib/mysql"
            "/var/log/mysql"
            "/var/lib/mysql-files"
            "/run/mysqld"
          ];
          ReadOnlyPaths = [ "/nix/store" ];
          InaccessiblePaths = [
            "/home"
            "/root"
            "/srv"
          ];

          # PrivateUsers = true;
          PrivateNetwork = true;
          PrivateMounts = true;
          ProcSubset = "pid";
          ProtectProc = "invisible";

          ProtectKernelLogs = true;
          ProtectClock = true;

          RestrictNamespaces = true;

          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "chown"
            "fchown"
            "lchown"
            "~@resources"
            "~@cpu-emulation"
            "~@debug"
            "~@mount"
            "~@obsolete"
          ];
          SystemCallErrorNumber = "EPERM";

          RestrictAddressFamilies = lib.mkOverride 0 [ "AF_UNIX" ];

          CapabilityBoundingSet = [ "" ];
          AmbientCapabilities = [ ];

          DevicePolicy = "closed";
          DeviceAllow = lib.mkOverride 0 [ "" ];

          KeyringMode = "private";
          IPAddressDeny = [
            "0.0.0.0/0"
            "::/0"
          ];

          RemoveIPC = true;

          UMask = "0077";

          RootDirectory = "/run/jails/mysqld";
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
            "/etc/static/pam.d"
            "/etc/my.cnf"
            "/etc/pam.d"
            "/run/user"
            "/etc/passwd"
            "/etc/group"
            "/etc/nsswitch.conf"
          ];
          BindPaths = [
            "/var/lib/mysql:/var/lib/mysql"
            "/var/log/mysql:/var/log/mysql"
            "/var/lib/mysql-files:/var/lib/mysql-files"
            "/run/mysqld:/run/mysqld"
          ];
        };
      };
    }
  );

}
