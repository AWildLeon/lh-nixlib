# Generate systemd tmpfiles rules for creating a service jail.
#
# Parameters:
# - serviceName: Name of the service (required)
# - user: User that owns service-specific directories (default: "root")
# - group: Group that owns service-specific directories (default: "root")
# - dataPaths: List of data directory paths that need to be created with service user permissions
#              (default: ["/var/lib/${serviceName}"])
# - extraPaths: List of additional paths to create with custom permissions
#
# Each path in extraPaths should be an attrset with:
# - path: The path relative to jail root (required)
# - mode: Permissions (default: "0755")
# - owner: Owner user (default: "root")
# - group: Owner group (default: "root")
#
# Example:
#   mkJailTmpfiles {
#     serviceName = "grafana";
#     user = "grafana";
#     group = "grafana";
#     dataPaths = [ "/var/lib/grafana" "/var/log/grafana" ];
#     extraPaths = [
#       { path = "/tmp"; mode = "1777"; }
#       { path = "/var/cache/grafana"; mode = "0750"; owner = "grafana"; group = "grafana"; }
#     ];
#   }
{ lib }:
{
  serviceName,
  user ? "root",
  group ? "root",
  dataPaths ? [ "/var/lib/${serviceName}" ],
  extraPaths ? [ ],
}:
let
  jailRoot = "/run/jails/${serviceName}";

  # Standard jail directory structure
  standardDirs = [
    # Jail root
    "d ${jailRoot} 0755 root root -"

    # etc directories (mount points for bind mounts)
    "d ${jailRoot}/etc 0755 root root -"
    "d ${jailRoot}/etc/ssl 0755 root root -"
    "d ${jailRoot}/etc/static 0755 root root -"

    # var directories
    "d ${jailRoot}/var 0755 root root -"
    "d ${jailRoot}/var/empty 0755 root root -"
    "d ${jailRoot}/var/lib 0755 root root -"

    # run directories
    "d ${jailRoot}/run 0755 root root -"
    "d ${jailRoot}/run/${serviceName} 0750 ${user} ${group} -"
    "d ${jailRoot}/run/current-system 0755 root root -"
    "d ${jailRoot}/run/current-system/sw 0755 root root -"
    "d ${jailRoot}/run/current-system/sw/bin 0755 root root -"
    "d ${jailRoot}/run/wrappers 0755 root root -"
    "d ${jailRoot}/run/wrappers/bin 0755 root root -"

    # nix store (read-only mount point)
    "d ${jailRoot}/nix 0755 root root -"
    "d ${jailRoot}/nix/store 0555 root root -"
  ];

  # Create data directories based on dataPaths
  dataRules = lib.flatten (
    map (
      dataPath:
      let
        # Split path into components to create parent directories
        pathComponents = lib.splitString "/" (lib.removePrefix "/" dataPath);
        # Create all parent directories progressively
        createParentDirs = lib.imap0 (
          i: _:
          let
            partialPath = "/" + lib.concatStringsSep "/" (lib.take (i + 1) pathComponents);
            jailPath = "${jailRoot}${partialPath}";
            # Last component gets service user permissions, others get root
            isLastComponent = (i + 1) == (lib.length pathComponents);
            owner = if isLastComponent then user else "root";
            groupOwner = if isLastComponent then group else "root";
            mode = if isLastComponent then "0750" else "0755";
          in
          "d ${jailPath} ${mode} ${owner} ${groupOwner} -"
        ) pathComponents;
      in
      createParentDirs
    ) dataPaths
  );

  # Extra custom paths
  extraRules = map (
    pathSpec:
    let
      path = pathSpec.path or (throw "extraPaths entries must have a 'path' attribute");
      mode = pathSpec.mode or "0755";
      owner = pathSpec.owner or "root";
      groupOwner = pathSpec.group or "root";
      jailPath = "${jailRoot}${path}";
    in
    "d ${jailPath} ${mode} ${owner} ${groupOwner} -"
  ) extraPaths;

in
standardDirs ++ dataRules ++ extraRules
