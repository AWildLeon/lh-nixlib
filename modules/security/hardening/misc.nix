{ lib, config, ... }:
{

  options.lh.security.hardenMisc = {
    enable = lib.mkEnableOption "Enable Hardening of /proc";
  };

  config = lib.mkIf config.lh.security.hardenMisc.enable {
    security.sudo.enable = lib.mkDefault false;
    environment.defaultPackages = lib.mkForce [ ];
    systemd.coredump.enable = lib.mkDefault false;
  };
}
