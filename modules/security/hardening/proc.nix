{ lib, config, ... }:
let
  cfg = config.lh.security.hardenProc;
in
{
  options.lh.security.hardenProc = {
    enable = lib.mkEnableOption "Enable Hardening of /proc";
  };

  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/proc" = {
        fsType = "proc";
        device = "proc";
        options = [
          "nosuid"
          "nodev"
          "noexec"
          "hidepid=2"
          "gid=${toString config.users.groups.proc.gid}"
        ];
        neededForBoot = true;
      };
    };

    # Allow only root for /proc
    users.groups.proc.gid = 500;

    systemd.services = {
      systemd-logind.serviceConfig.SupplementaryGroups = [ "proc" ];
      "user@".serviceConfig.SupplementaryGroups = [ "proc" ];
    }
    // lib.mkIf config.security.polkit.enable {
      polkit.serviceConfig.SupplementaryGroups = [ "proc" ];
    };
  };

}
