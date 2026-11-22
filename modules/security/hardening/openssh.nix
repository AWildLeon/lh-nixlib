{ lib, config, ... }:
let
  cfg = config.lh.security.hardenOpenSSH;

  # Original list, kept as the default so existing users see no change.
  legacy = {
    Ciphers = [
      "aes128-ctr"
      "aes256-ctr,aes192-ctr"
      "aes128-gcm@openssh.com"
      "aes256-gcm@openssh.com"
    ];
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
  };

  # Needs OpenSSH >= 9.9 (mlkem768x25519-sha256). Hybrid post-quantum KEX
  # first, curve25519 as the fallback for older clients; no finite-field DH.
  # AEAD ciphers first; CTR only pairs with the encrypt-then-MAC MACs below,
  # so no non-ETM MAC is offered.
  modern = {
    Ciphers = [
      "chacha20-poly1305@openssh.com"
      "aes256-gcm@openssh.com"
      "aes128-gcm@openssh.com"
      "aes256-ctr"
      "aes192-ctr"
      "aes128-ctr"
    ];
    KexAlgorithms = [
      "mlkem768x25519-sha256"
      "sntrup761x25519-sha512"
      "sntrup761x25519-sha512@openssh.com"
      "curve25519-sha256"
      "curve25519-sha256@libssh.org"
    ];
    Macs = [
      "hmac-sha2-512-etm@openssh.com"
      "hmac-sha2-256-etm@openssh.com"
      "umac-128-etm@openssh.com"
    ];
  };
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
      modernAlgorithms = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Offer only current algorithms: hybrid post-quantum KEX
          (mlkem768x25519, sntrup761x25519) with curve25519 fallback, no
          finite-field DH, and encrypt-then-MAC MACs only. Requires
          OpenSSH >= 9.9 on the server; clients older than that negotiate
          curve25519. When false, the previous, broader list is used.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      settings = (if cfg.modernAlgorithms then modern else legacy) // {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = cfg.passwordAuthentication;
      };
    };
  };
}
