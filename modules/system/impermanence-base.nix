{
  config,
  lib,
  pkgs,
  options,
  utils,
  ...
}:

let
  cfg = config.lh.system.impermanence;
  cfgFs = cfg.filesystem;
  cfgBtrfs = cfgFs.btrfs;
  cfgZfs = cfgFs.zfs;

  isBtrfs = cfgFs.fsType == "btrfs";
  isZfs = cfgFs.fsType == "zfs";

  btrfsDevice =
    if cfgBtrfs.rootDevice != "" then cfgBtrfs.rootDevice else config.fileSystems."/".device;
  zfsPool = builtins.head (lib.splitString "/" cfgZfs.rootDataset);

  hasImpermanence =
    builtins.hasAttr "environment" options && builtins.hasAttr "persistence" options.environment;
in
{
  options.lh.system.impermanence = {
    enable = lib.mkEnableOption "Enable impermanence configuration with filesystem rollback on boot";
    removeHome = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Remove /home from persistence and recreate it on boot (btrfs only)";
    };

    filesystem = {
      fsType = lib.mkOption {
        type = lib.types.enum [
          "btrfs"
          "zfs"
        ];
        default = "btrfs";
        description = "Filesystem type used for impermanence rollback";
      };

      btrfs = {
        rootSubvolume = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = "Btrfs root subvolume to delete and recreate on each boot";
        };
        homeSubvolume = lib.mkOption {
          type = lib.types.str;
          default = "home";
          description = "Btrfs home subvolume to recreate on boot when removeHome is true";
        };
        rootDevice = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Btrfs block device path (auto-detected from fileSystems.\"/\" if empty)";
        };
      };

      zfs = {
        rootDataset = lib.mkOption {
          type = lib.types.str;
          default = "rpool/local/root";
          description = "ZFS dataset for the root filesystem";
        };
        blankSnapshot = lib.mkOption {
          type = lib.types.str;
          default = "rpool/local/root@blank";
          description = "ZFS snapshot to rollback root to on every boot (must be pre-created after install)";
        };
      };
    };

    persistentPath = lib.mkOption {
      type = lib.types.str;
      default = "/persistent";
      description = "Path to the persistent storage mount point";
    };

    persistentDirectories = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
      default = [ ];
      description = "Directories to persist across reboots";
      apply = lib.lists.unique;
    };

    persistentFiles = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
      default = [ ];
      description = "Files to persist across reboots";
    };

    enablePersistence = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable environment.persistence configuration (requires impermanence module)";
    };
  };

  config = lib.mkMerge [
    # Shared base configuration
    (lib.mkIf cfg.enable {
      lh.system.impermanence.persistentDirectories = [
        "/var/lib/nixos"
        "/var/log"
        "/var/lib/cloud/"
        "/var/lib/systemd/journal"
        "/var/lib/systemd/coredump"
        "/var/lib/NetworkManager"
        {
          directory = "/etc/NetworkManager/system-connections";
          mode = "0700";
        }
        {
          directory = "/var/lib/private/";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.security.acme.acceptTerms [
        {
          directory = "/var/lib/acme/";
          mode = "0755";
          user = "acme";
          group = "acme";
        }
      ];

      lh.system.impermanence.persistentFiles = [ "/etc/machine-id" ];

      boot.initrd.systemd.emergencyAccess = lib.mkDefault true;
      fileSystems."${cfg.persistentPath}".neededForBoot = true;
    })

    # Btrfs rollback service
    (lib.mkIf (cfg.enable && isBtrfs) {
      # util-linuxMinimal (mount) is already in the systemd initrd; btrfs-progs and
      # coreutils are not, so include them explicitly.
      boot.initrd.systemd.initrdBin = with pkgs; [
        btrfs-progs
        coreutils
      ];

      boot.initrd.systemd.services.rollback = {
        description = "Rollback btrfs root to a pristine state";
        wantedBy = [ "initrd.target" ];
        after = [
          "local-fs-pre.target"
          "${utils.escapeSystemdPath btrfsDevice}.device"
        ];
        before = [ "sysroot.mount" ];
        # NOTE: util-linuxMinimal, not util-linux. The full package splits `mount`
        # into a separate output that is not present in the systemd initrd.
        path = with pkgs; [
          btrfs-progs
          coreutils
          util-linuxMinimal
        ];
        unitConfig = {
          DefaultDependencies = "no";
          OnFailure = "emergency.target";
          OnFailureJobMode = "replace-irreversibly";
        };
        serviceConfig.Type = "oneshot";
        script =
          ''
            set -euo pipefail
            mkdir /btrfs_tmp
            mount "${btrfsDevice}" /btrfs_tmp

            delete_subvolume_recursively() {
                IFS=$'\n'
                for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                    delete_subvolume_recursively "/btrfs_tmp/$i"
                done
                btrfs subvolume delete "$1"
            }
            echo "Deleting old root subvolume"
            delete_subvolume_recursively /btrfs_tmp/${cfgBtrfs.rootSubvolume}
          ''
          + lib.optionalString cfg.removeHome ''
            echo "Recreating home subvolume"
            delete_subvolume_recursively /btrfs_tmp/${cfgBtrfs.homeSubvolume}_previous || true
            mv /btrfs_tmp/${cfgBtrfs.homeSubvolume} /btrfs_tmp/${cfgBtrfs.homeSubvolume}_previous
            btrfs subvolume create /btrfs_tmp/${cfgBtrfs.homeSubvolume}

            # Recreate home subfolder for each user with proper permissions
            ${lib.concatMapStrings (u: ''
              mkdir -p /btrfs_tmp/${cfgBtrfs.homeSubvolume}/${lib.removePrefix "/home/" u.home}
              chown ${toString u.uid}:${
                toString config.users.groups.${u.group}.gid
              } /btrfs_tmp/${cfgBtrfs.homeSubvolume}/${lib.removePrefix "/home/" u.home}
              chmod ${u.homeMode} /btrfs_tmp/${cfgBtrfs.homeSubvolume}/${lib.removePrefix "/home/" u.home}
            '') (lib.filter (u: u.createHome && lib.hasPrefix "/home/" u.home && u.uid != null) (lib.attrValues config.users.users))}
          ''
          + ''
            echo "Recreating root subvolume"
            btrfs subvolume create /btrfs_tmp/${cfgBtrfs.rootSubvolume}

            umount /btrfs_tmp
          '';
      };
    })

    # ZFS rollback service
    (lib.mkIf (cfg.enable && isZfs) {
      boot.initrd.systemd.initrdBin = with pkgs; [ zfs ];

      boot.initrd.systemd.services.rollback = {
        description = "Rollback ZFS root dataset to blank snapshot";
        wantedBy = [ "initrd.target" ];
        after = [ "zfs-import-${zfsPool}.service" ];
        before = [ "sysroot.mount" ];
        path = with pkgs; [ zfs ];
        unitConfig = {
          DefaultDependencies = "no";
          OnFailure = "emergency.target";
          OnFailureJobMode = "replace-irreversibly";
        };
        serviceConfig.Type = "oneshot";
        script = ''
          set -euo pipefail
          echo "Rolling back ${cfgZfs.rootDataset} to ${cfgZfs.blankSnapshot}"
          zfs rollback -r ${cfgZfs.blankSnapshot}
        '';
      };
    })

    # Persistence configuration (only when impermanence module is available)
    (lib.mkIf (cfg.enable && cfg.enablePersistence) (
      lib.optionalAttrs hasImpermanence {
        environment.persistence."${cfg.persistentPath}" = {
          hideMounts = true;
          directories = cfg.persistentDirectories;
          files = cfg.persistentFiles;
        };
      }
    ))
  ];
}
