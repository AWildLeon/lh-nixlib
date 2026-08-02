{ lib, config, ... }:
let
  cfg = config.lh.security.hardenOpenSSH;
in
{
  options = {
    lh.security.hardenOpenSSH = {
      enable = lib.mkEnableOption "Enable Hardening of OpenSSH";
      passwordAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to allow password authentication for OpenSSH";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      settings = {
        Ciphers = [
          "aes128-ctr"
          "aes256-ctr,aes192-ctr"
          "aes128-gcm@openssh.com"
          "aes256-gcm@openssh.com"
        ];
        KbdInteractiveAuthentication = false;
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "sntrup761x25519-sha512@openssh.com"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
        Macs = [
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512"
          "hmac-sha2-512-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
        PasswordAuthentication = cfg.passwordAuthentication;
      };
    };
  };
}
