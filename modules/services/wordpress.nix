{ config, lib, ... }:
let
  cfg = config.lh.services.wordpress;
in
{
  options.lh.services.wordpress = {
    enable = lib.mkEnableOption "WordPress service";
    # Submodule
    sites = lib.mkOption {
      type = lib.types.attrs;
      description = "WordPress sites configuration";
      default = throw "You must define at least one WordPress site";
    };
  };
  config = lib.mkIf cfg.enable {
    lh = {
      services.db.mysql.enable = lib.mkDefault true;
      services.nginx = {
        enable = true;
        ReadWritePaths = [ "/var/lib/wordpress" ];
      };
      system.impermanence.persistentDirectories = [
        {
          directory = "/var/lib/wordpress";
          mode = "0755";
        }
      ];
    };

    services.wordpress = {
      webserver = "nginx";
      inherit (cfg) sites;
    };
  };
}
