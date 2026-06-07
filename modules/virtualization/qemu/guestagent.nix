{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.lh.virtualization.qemu.hardenedGuestAgent =
    lib.mkEnableOption "Harden the QEMU Guest Agent by blocking dangerous RPCs";

  # QEMU Guest Agent Hardening
  config = lib.mkIf config.lh.virtualization.qemu.hardenedGuestAgent {

    services.qemuGuest.enable = true;
    systemd.services.qemu-guest-agent.serviceConfig.ExecStart =
      lib.mkForce "${pkgs.qemu_kvm.ga}/bin/qemu-ga --statedir /run/qemu-ga --block-rpcs=guest-set-time,guest-file-open,guest-file-close,guest-file-read,guest-file-write,guest-file-seek,guest-file-flush,guest-get-fsinfo,guest-set-user-password,guest-get-memory-blocks,guest-set-memory-blocks,guest-exec-status,guest-exec,guest-get-users,guest-get-osinfo,guest-get-devices,guest-ssh-get-authorized-keys,guest-ssh-add-authorized-keys,guest-ssh-remove-authorized-keys";
  };
}
