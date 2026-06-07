{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

with lib;

let
  cfg = config.lh.cosmetic.motd;

  inherit (cfg) width;
  inherit (cfg) font;
  rule = lib.concatStrings (lib.replicate width "=");

  # Compute FQDN locally to avoid evaluation issues during flake check
  hostName = config.networking.hostName or "";
  inherit (config.networking) domain;
  fqdn = "${hostName}${if domain != null && domain != "" then ".${domain}" else ""}";

  # Use fqdn if not empty, else hostname
  name = if fqdn != "" then fqdn else hostName;

  # Generate clean ASCII (escape \ -> \\ for literal display; trim trailing spaces)
  # Handle empty hostname gracefully for flake check
  hostnameAscii =
    if name == "" then
      # Use a simple string for empty hostnames to avoid derivation building during flake check
      builtins.toFile "hostname-ascii-empty" "Unknown Host"
    else
      pkgs.runCommand "hostname-ascii" { } ''
        ${pkgs.figlet}/bin/figlet -f ${font} -w ${toString width} -k -- "${name}" \
          | sed -e 's/[[:space:]]*$//' -e 's/\\/\\\\/g' > $out
      '';

  # ANSI wrappers for TTY stability
  esc = "\\x1b";
  prelude = "${esc}[?7l${esc}(B${esc}[0m${esc}[3g"; # no-wrap, sane charset, reset, clear tabs
  postlude = "${esc}[0m${esc}[?7h"; # reset + re-enable wrap

  # Build /etc/issue with escapes so agetty won’t mangle it
  issueAnsi = pkgs.runCommand "issue-ansi" { } ''
    {
      printf '${prelude}'
      cat ${hostnameAscii}

      echo
      echo '${rule}'
      echo
      echo '${cfg.warningText}'
      echo
      echo 'System Information:'
      echo '├─ OS: NixOS ${config.system.nixos.release} (${config.system.nixos.codeName})'
      echo '├─ Flake Revision: ${inputs.self.shortRev or inputs.self.dirtyShortRev or "dirty"}'
      echo '├─ Kernel: ${config.boot.kernelPackages.kernel.version or "unknown"}'
      echo '├─ Timezone: ${config.time.timeZone}'
      echo '└─ Locale: ${config.i18n.defaultLocale}'
      echo
      echo '${rule}'

      printf '${postlude}\n'
    } > $out
  '';

  # Plaintext MOTD (SSH), no escapes needed
  issueTextDrv = pkgs.runCommand "issue-text" { } ''
    cat ${hostnameAscii} > $out
    cat >> $out <<'EOF'

    ${rule}

    ${cfg.warningText}

    System Information:
    ├─ OS: NixOS ${config.system.nixos.release} (${config.system.nixos.codeName})
    ├─ Flake Revision: ${inputs.self.shortRev or inputs.self.dirtyShortRev or "dirty"}
    ├─ Kernel: ${config.boot.kernelPackages.kernel.version or "unknown"}
    ├─ Timezone: ${config.time.timeZone}
    └─ Locale: ${config.i18n.defaultLocale}

    ${rule}
    EOF
  '';
in
{
  options.lh.cosmetic.motd = {
    enable = mkEnableOption "Enable custom MOTD and issue configuration";

    width = mkOption {
      type = types.int;
      default = 100;
      description = "Width of the ASCII art and rule lines";
    };

    font = mkOption {
      type = types.str;
      default = "slant";
      description = "Figlet font to use for hostname ASCII art";
    };

    warningText = mkOption {
      type = types.str;
      default = "Unauthorized access to this system is prohibited.";
      description = "Warning text to display in MOTD and issue";
    };

    enableConsoleFont = mkOption {
      type = types.bool;
      default = true;
      description = "Enable custom console font configuration";
    };

    consoleFont = mkOption {
      type = types.str;
      default = "ter-v18n";
      description = "Console font to use";
    };
  };

  config = mkIf cfg.enable {
    environment = mkIf (fqdn != "") {
      # local MOTD
      etc."motd".source = issueTextDrv;

      # TTY login screen (with VT escapes)
      etc."issue".source = issueAnsi;
    };

    boot.kernelParams = [ "vt.default_utf8=1" ];

    console = mkIf cfg.enableConsoleFont {
      font = cfg.consoleFont;
      packages = [ pkgs.terminus_font ];
    };
  };
}
