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

  # The templates carry a placeholder for the flake revision. `revision.mode`
  # decides where it is filled in:
  #   "build"   -- at build time, from `revision.value`. Simple, but the value
  #                usually is the flake's rev, which changes /etc (and so the
  #                whole system closure) on every commit.
  #   "runtime" -- by lh-motd.service, from `revision.file`, which the deployer
  #                writes outside the closure. The closure stays commit-independent.
  placeholder = "@FLAKE_REV@";
  runDir = "/run/lh-motd";
  runtime = cfg.revision.mode == "runtime";

  bakeRevision =
    name: tpl:
    pkgs.runCommand name { rev = cfg.revision.value; } ''
      substitute ${tpl} $out --replace-fail ${placeholder} "$rev"
    '';

  renderMotd = pkgs.writeShellScript "lh-motd-render" ''
    set -euo pipefail
    rev=unknown
    if [[ -r ${lib.escapeShellArg cfg.revision.file} ]]; then
      read -r candidate < ${lib.escapeShellArg cfg.revision.file} || true
      # Only a (short) hash, optionally -dirty: the value lands in sed and on TTYs.
      if [[ ''${candidate:-} =~ ^[0-9a-f]{7,40}(-dirty)?$ ]]; then
        rev=$candidate
      fi
    fi
    ${pkgs.coreutils}/bin/mkdir -p ${runDir}
    for f in motd:${issueTextDrv} issue:${issueAnsi}; do
      name=''${f%%:*}
      ${pkgs.gnused}/bin/sed "s/${placeholder}/$rev/g" "''${f#*:}" > ${runDir}/"$name".tmp
      ${pkgs.coreutils}/bin/mv ${runDir}/"$name".tmp ${runDir}/"$name"
    done
  '';

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
      echo '├─ Flake Revision: @FLAKE_REV@'
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
    ├─ Flake Revision: @FLAKE_REV@
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

    revision = {
      mode = mkOption {
        type = types.enum [
          "build"
          "runtime"
        ];
        default = "build";
        description = ''
          Where the flake revision shown in MOTD and issue comes from.

          `build` bakes `revision.value` in at build time. If that is the flake's
          own revision (the default), every commit changes the system closure.

          `runtime` renders /etc/motd and /etc/issue at boot and whenever
          `revision.file` changes, so the closure does not depend on the commit.
          Something outside the closure must write that file on deploy, e.g. a
          Colmena `deployment.keys` entry set in the hive (not in a NixOS module,
          where Colmena's key units would put it back into the closure).
        '';
      };

      value = mkOption {
        type = types.str;
        default = inputs.self.shortRev or inputs.self.dirtyShortRev or "dirty";
        defaultText = lib.literalExpression ''inputs.self.shortRev or inputs.self.dirtyShortRev or "dirty"'';
        description = "Revision baked in when `revision.mode` is `build`.";
      };

      file = mkOption {
        type = types.str;
        default = "/var/lib/lh/flake-revision";
        description = ''
          File read when `revision.mode` is `runtime`: one line, a hex revision
          (7-40 characters), optionally suffixed `-dirty`. Missing or malformed
          shows `unknown`.
        '';
      };
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
      etc."motd".source = if runtime then "${runDir}/motd" else bakeRevision "motd" issueTextDrv;

      # TTY login screen (with VT escapes)
      etc."issue".source = if runtime then "${runDir}/issue" else bakeRevision "issue" issueAnsi;
    };

    systemd = mkIf (fqdn != "" && runtime) {
      services.lh-motd = {
        description = "Render /etc/motd and /etc/issue with the deployed flake revision";
        wantedBy = [ "multi-user.target" ];
        # gettys and logins start after systemd-user-sessions.
        before = [ "systemd-user-sessions.service" ];
        # Re-render on every switch too, so a changed template shows up at once.
        restartIfChanged = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = renderMotd;
        };
      };

      # The deployer rewrites the file after activation; pick that up.
      paths.lh-motd = {
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathChanged = cfg.revision.file;
          Unit = "lh-motd-refresh.service";
        };
      };
      services.lh-motd-refresh = {
        description = "Re-render /etc/motd and /etc/issue after a deploy";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = renderMotd;
        };
      };
    };

    boot.kernelParams = [ "vt.default_utf8=1" ];

    console = mkIf cfg.enableConsoleFont {
      font = cfg.consoleFont;
      packages = [ pkgs.terminus_font ];
    };
  };
}
