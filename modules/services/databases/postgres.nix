{ lib, config, ... }:
let
  cfg = config.lh.services.db.postgres;
in
{
  options.lh.services.db.postgres = {
    enable = lib.mkEnableOption "PostgreSQL database server";
  };

  config = lib.mkIf cfg.enable {
    services.postgresql.enable = true;
    lh.system.impermanence.persistentDirectories = [
      {
        directory = "/var/lib/postgresql";
        mode = "0700";
        user = "postgres";
        group = "postgres";
      }
    ];
  };

}
