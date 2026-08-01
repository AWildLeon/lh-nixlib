{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lh.security.fail2ban;
  firewallBackend = config.networking.firewall.backend;
  firewallActions = {
    iptables = {
      multiport = "iptables-multiport";
      allports = "iptables-allports";
    };
    nftables = {
      multiport = "nftables-multiport";
      allports = "nftables-allports";
    };
    firewalld = {
      multiport = "firewallcmd-multiport";
      allports = "firewallcmd-allports";
    };
  };
in
{
  options.lh.security.fail2ban = {
    enable = lib.mkEnableOption "Fail2ban with opinionated defaults and service integrations";

    package = lib.mkPackageOption pkgs "fail2ban" { };

    bantime = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "How long an address is banned after exceeding the retry limit.";
    };

    findtime = lib.mkOption {
      type = lib.types.str;
      default = "10m";
      description = "Time window in which failed attempts are counted.";
    };

    maxretry = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of failures allowed during findtime before an address is banned.";
    };

    whitelist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.168.0.0/16"
        "2001:db8::42"
      ];
      description = "Addresses, CIDR ranges, or DNS names that Fail2ban must never ban.";
    };

    bantimeIncrement = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Increase ban durations for repeat offenders.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      inherit (cfg)
        package
        bantime
        maxretry
        ;

      ignoreIP = cfg.whitelist;
      packageFirewall =
        if firewallBackend == "firewalld" then
          config.services.firewalld.package
        else
          config.networking.firewall.package;
      banaction = firewallActions.${firewallBackend}.multiport;
      banaction-allports = firewallActions.${firewallBackend}.allports;

      bantime-increment = {
        enable = cfg.bantimeIncrement;
        maxtime = lib.mkIf cfg.bantimeIncrement "1w";
        overalljails = lib.mkIf cfg.bantimeIncrement true;
      };

      jails.DEFAULT.settings.findtime = cfg.findtime;
    };

    lh.system.impermanence.persistentDirectories = [
      {
        directory = "/var/lib/fail2ban";
        mode = "0750";
      }
    ];
  };
}
