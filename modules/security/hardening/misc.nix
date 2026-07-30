{ lib, config, ... }:
{

  options.lh.security.hardenMisc = {
    enable = lib.mkEnableOption "Enable Hardening of /proc";
  };

  config = lib.mkIf config.lh.security.hardenMisc.enable {
    security.sudo = {
      enable = true;
      execWheelOnly = true;
      wheelNeedsPassword = true;
      extraConfig = ''
        Defaults lecture = never
      '';
    };
    environment.defaultPackages = lib.mkForce [ ];
    systemd.coredump.enable = lib.mkDefault false;
  };
}
