{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.lh.networking.staticInterfaceNames;
in
{
  options.lh.networking.staticInterfaceNames = {
    interfaces = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        "aa:bb:cc:dd:ee:ff" = "wan";
        "11:22:33:44:55:66" = "lan1";
        "77:88:99:aa:bb:cc" = "lan2";
      };
      description = ''
        Mapping of MAC addresses to interface names.
        The key is the MAC address and the value is the desired interface name.
      '';
    };
  };

  # .link rather than a udev NAME= rule: NAME= only applies on `add`, so a
  # mapping deployed after the interface exists would not take effect until the
  # next boot. 10- sorts ahead of systemd's 99-default.link.
  config = mkIf (cfg.interfaces != { }) {
    systemd.network.links = mapAttrs' (
      mac: name:
      nameValuePair "10-lh-${name}" {
        matchConfig.MACAddress = mac;
        linkConfig.Name = name;
      }
    ) cfg.interfaces;
  };
}
