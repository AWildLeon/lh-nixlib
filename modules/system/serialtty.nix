{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lh.system.serialtty;
  resizeSerialTerminalScript = pkgs.writeShellScriptBin "ResizeSerialTerminal" ''
    #!${pkgs.stdenv.shell}
    old=$(${pkgs.coreutils-full}/bin/stty -g)
    ${pkgs.coreutils-full}/bin/stty raw -echo min 0 time 5

    printf '\0337\033[r\033[999;999H\033[6n\0338' > /dev/tty
    IFS='[;R' read -r _ rows cols _ < /dev/tty

    ${pkgs.coreutils-full}/bin/stty "$old"

    echo "Resizing serial terminal to $cols columns and $rows rows"

    ${pkgs.coreutils-full}/bin/stty cols "$cols" rows "$rows"
  '';
in
{
  options.lh.system.serialtty = {
    enable = lib.mkEnableOption "Whether to enable serial console output only (GPU-Less System)";
    device = lib.mkOption {
      type = lib.types.str;
      default = "ttyS0";
      description = "The serial device to use for console output";
    };
    baudRate = lib.mkOption {
      type = lib.types.str;
      default = "115200";
      description = "The baud rate to use for the serial console";
    };
    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable auto-login on the serial console";
    };
    autoLoginUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "The user to auto-login as on the serial console (if autoLogin is enabled)";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ resizeSerialTerminalScript ];

    boot.kernelParams = [ "console=${cfg.device},${cfg.baudRate}n8" ];
    systemd.services = {

      "serial-getty@" = {
        enable = false;
      };

      # Configure our own serial-getty@ttyS0 service
      "serial-getty@${cfg.device}" = {
        enable = true;
        wantedBy = [ "getty.target" ];
        after = [ "systemd-user-sessions.service" ];
        wants = [ "systemd-user-sessions.service" ];
        serviceConfig = {
          Type = "idle";
          Restart = "always";
          Environment = "TERM=vt220";
          ExecStart = "${pkgs.util-linux}/bin/agetty --login-program ${pkgs.shadow}/bin/login --noclear --keep-baud ${cfg.device} ${cfg.baudRate},57600,38400,9600 vt220 ${(lib.optionalString cfg.autoLogin " --autologin ${cfg.autoLoginUser}")}";
          UtmpIdentifier = "${cfg.device}";
          StandardInput = "tty";
          StandardOutput = "tty";
          TTYPath = "/dev/${cfg.device}";
          TTYReset = "yes";
          TTYVHangup = "yes";
          IgnoreSIGPIPE = "no";
          SendSIGHUP = "yes";
        };
      };
    };
  };

}
