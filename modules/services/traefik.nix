{
  lib,
  config,
  lh,
  options,
  inputs,
  pkgs,
  ...
}:
with lib;
let

  cfg = config.lh.services.traefik;
  # Pick the container runtime socket automatically
  socketPath =
    if config.virtualisation.podman.enable then "/run/podman/podman.sock" else "/var/run/docker.sock";

  # Where HAProxy will expose its own Unix listener for clients (curl, traefik, etc.)
  bindSocket = "/run/haproxy/docker-unpriv.sock";

  socketProxyConfig = ''
    global
        log stdout format raw daemon notice
        maxconn 4000

        # Admin / stats socket (optional)
        stats socket /run/haproxy/admin.sock mode 660 level admin
        server-state-file /var/lib/haproxy/server-state

    defaults
        mode http
        log global
        option httplog
        option dontlognull
        option http-server-close
        option redispatch
        retries 3
        timeout http-request 10s
        timeout queue 1m
        timeout connect 10s
        timeout client 10m
        timeout server 10m
        timeout http-keep-alive 10s
        timeout check 10s
        maxconn 3000
        load-server-state-from-file global

    # --- Backends ---
    backend dockerbackend
        # IMPORTANT: unix socket requires the unix@ prefix
        server dockersocket unix@${socketPath}

    backend docker-events
        server dockersocket unix@${socketPath}
        timeout server 0

    # --- Frontend ---
    frontend dockerfrontend
        # Bind HAProxy's public-facing Unix socket; set perms so non-root clients can connect
        bind unix@${bindSocket} user haproxy group docker mode 666

        # Bypass Deny for those.
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/containers/[a-zA-Z0-9_.-]+/(restart|stop|kill)$ } METH_POST { env(ALLOW_RESTARTS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/containers/[a-zA-Z0-9_.-]+/start$ } METH_POST { env(ALLOW_START) -m bool }

        # Allow-list of Docker API segments via env flags (flip to 1 with systemd env if you want)
        http-request deny unless METH_GET || { env(POST) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/containers/[a-zA-Z0-9_.-]+/((stop)|(restart)|(kill)) } { env(ALLOW_RESTARTS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/containers/[a-zA-Z0-9_.-]+/start } { env(ALLOW_START) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/containers/[a-zA-Z0-9_.-]+/stop } { env(ALLOW_STOP) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/auth } { env(AUTH) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/build } { env(BUILD) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/commit } { env(COMMIT) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/configs } { env(CONFIGS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/containers } { env(CONTAINERS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/distribution } { env(DISTRIBUTION) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/events } { env(EVENTS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/exec } { env(EXEC) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/grpc } { env(GRPC) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/images } { env(IMAGES) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/info } { env(INFO) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/networks } { env(NETWORKS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/nodes } { env(NODES) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/_ping } { env(PING) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/plugins } { env(PLUGINS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/secrets } { env(SECRETS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/services } { env(SERVICES) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/session } { env(SESSION) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/swarm } { env(SWARM) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/system } { env(SYSTEM) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/tasks } { env(TASKS) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/version } { env(VERSION) -m bool }
        http-request allow if { path,url_dec -m reg -i ^(/v[\d\.]+)?/volumes } { env(VOLUMES) -m bool }
        http-request deny

        default_backend dockerbackend
        use_backend docker-events if { path,url_dec -m reg -i ^(/v[\d\.]+)?/events }
  '';

  TraefikFormat = pkgs.formats.toml { };
in
{
  options = {
    lh.services.traefik = {
      enable = mkEnableOption "Traefik reverse proxy";
      environmentFiles = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of environment files to load for Traefik configuration";
      };
      dataDir = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory to store Traefik data files (certificates, etc.)";
      };
      dynamicConfig = mkOption {
        inherit (TraefikFormat) type;
        default = { };
        description = "Dynamic configuration for Traefik (routers, services, middlewares)";
      };

      cert_resolvers = mkOption {
        inherit (TraefikFormat) type;
        default = { };
        description = ''
          A set of certificate resolvers to use for automatic TLS certificate management.
          Each resolver should be defined as an attribute set with the necessary configuration.
        '';
      };

      additionalEntrypoints = mkOption {
        inherit (TraefikFormat) type;
        default = { };
        description = ''
          Additional entry points to define for Traefik.
          Each entry point should be defined as an attribute set with the necessary configuration.
        '';
      };
    };
  };

  config =
    let
      haveImpermanence = options ? environment && options.environment ? persistence;
      persistenceDef =
        if haveImpermanence then
          {
            environment.persistence."/persistent".directories = [
              {
                directory = "/var/lib/traefik";
                user = "traefik";
                group = "traefik";
                mode = "u=rwx,g=,o=";
              }
            ]
            ++ optionals (cfg.dataDir != null) [
              {
                directory = cfg.dataDir;
                user = "traefik";
                group = "traefik";
                mode = "u=rwx,g=,o=";
              }
            ];
          }
        else
          { };
    in
    mkIf cfg.enable (
      persistenceDef
      // {
        users = {

          users.traefik = {
            isSystemUser = true;
            group = "traefik";
          };

          groups.traefik = {
            gid = 9443;
          };
        };
        services = {

          traefik = {
            enable = true;
            package = inputs.lh-nixlib.packages.${pkgs.stdenv.hostPlatform.system}.traefik;
            staticConfigOptions = {
              global = {
                checkNewVersion = false;
                sendAnonymousUsage = false;
              };

              log = {
                level = "INFO";
                format = "common";
              };

              api = {
                dashboard = true;
              };

              entryPoints = {
                web = {
                  address = ":80";
                  http = {
                    redirections = {
                      entryPoint = {
                        to = "websecure";
                        scheme = "https";
                      };
                    };
                  };
                };
                websecure = {
                  address = ":443";
                  http2 = {
                    maxConcurrentStreams = 1000;
                  };
                  reusePort = true;
                };
              }
              // cfg.additionalEntrypoints;

              certificatesResolvers = mkIf (cfg.cert_resolvers != { }) cfg.cert_resolvers;

              serversTransport = {
                insecureSkipVerify = true; # Skip TLS verification for backend servers
                forwardingTimeouts = {
                  responseHeaderTimeout = "300s";
                  readIdleTimeout = "300s";
                  idleConnTimeout = "300s";
                };
              };

              providers = mkIf (config.virtualisation.docker.enable || config.virtualisation.podman.enable) {
                docker = {
                  endpoint = "unix://${bindSocket}";
                  watch = true;
                  exposedByDefault = false; # Only expose containers with labels
                };
              };
            };
            dynamicConfigOptions = cfg.dynamicConfig;
            inherit (cfg) environmentFiles;
          };

          # Only enable HAProxy when a container runtime is enabled
          haproxy = mkIf (config.virtualisation.docker.enable || config.virtualisation.podman.enable) {
            enable = true;
            config = socketProxyConfig;

            # Run as group 'docker' so it can talk to /var/run/docker.sock or /run/podman/podman.sock
            group = "docker";
          };
        };

        systemd = {
          services = {
            traefik = {
              preStart = ''
                ${pkgs.coreutils}/bin/mkdir -p /var/lib/traefik/acme
                if [ ! -f /var/lib/traefik/acme/acme.json ]; then
                  ${pkgs.coreutils}/bin/install -m 600 /dev/null /var/lib/traefik/acme/acme.json
                fi
              '';
              serviceConfig = {
                PrivateDevices = true;
                PrivateUsers = false;
                ProcSubset = "pid";
                ProtectControlGroups = true;
                ProtectProc = "invisible";

                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectKernelLogs = true;
                ProtectClock = true;
                ProtectHostname = true;
                RestrictSUIDSGID = true;
                RestrictRealtime = true;
                RestrictNamespaces = true;
                ProtectSystem = lib.mkForce "strict";
                ReadWritePaths = [
                  cfg.dataDir
                  "/var/lib/traefik"
                ];
                RemoveIPC = true;
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                SystemCallArchitectures = "native";
                SystemCallFilter = [
                  "~@privileged"
                  "~@cpu-emulation"
                  "~@debug"
                  "~@mount"
                  "~@obsolete"
                ];
                SystemCallErrorNumber = "EPERM";
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
                AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
                UMask = "0077";

                RootDirectory = "/run/jails/traefik";

                MountAPIVFS = true;

                BindReadOnlyPaths = [
                  "/nix/store"
                  "/etc/ssl"
                  "/etc/resolv.conf"
                  "/etc/hosts"
                  "/run/current-system/sw/bin"
                  "/run/wrappers/bin"
                  "/etc/static/ssl"
                ]
                ++ optionals (config.virtualisation.docker.enable || config.virtualisation.podman.enable) [
                  "/run/haproxy/"
                ];
                BindPaths = [
                  "/var/lib/traefik:/var/lib/traefik"
                ]
                ++ optionals (cfg.dataDir != null) [ "${cfg.dataDir}:${cfg.dataDir}" ];
              };
            };

            haproxy =
              mkIf ((config.virtualisation.docker.enable || config.virtualisation.podman.enable) && cfg.enable)
                {
                  serviceConfig = {
                    Environment = [
                      # flip to 1 to allow those verbs/paths
                      "POST=0"
                      "ALLOW_RESTARTS=1"
                      "ALLOW_START=1"
                      "ALLOW_STOP=1"
                      "AUTH=0"
                      "BUILD=0"
                      "COMMIT=0"
                      "CONFIGS=0"
                      "CONTAINERS=1"
                      "DISTRIBUTION=0"
                      "EVENTS=1"
                      "EXEC=0"
                      "GRPC=0"
                      "IMAGES=1"
                      "INFO=1"
                      "NETWORKS=1"
                      "NODES=0"
                      "PING=1"
                      "PLUGINS=0"
                      "SECRETS=0"
                      "SERVICES=0"
                      "SESSION=0"
                      "SWARM=0"
                      "SYSTEM=0"
                      "TASKS=0"
                      "VERSION=1"
                      "VOLUMES=1"
                    ];

                    ReadWritePaths = [ "/run/haproxy" ];

                    ProtectSystem = "strict";
                    InaccessiblePaths = [
                      "/root"
                      "/home"
                      "/docker"
                    ];

                    # Prozess-/Kernel-Isolation
                    PrivateTmp = true;
                    PrivateMounts = true;
                    PrivateDevices = true;
                    DevicePolicy = "closed";
                    NoNewPrivileges = true;
                    RestrictSUIDSGID = true;
                    RestrictRealtime = true;
                    RestrictNamespaces = true;
                    LockPersonality = true;
                    MemoryDenyWriteExecute = true;

                    ProtectProc = "invisible";
                    ProcSubset = "pid";
                    ProtectKernelModules = true;
                    ProtectKernelTunables = true;
                    ProtectKernelLogs = true;
                    ProtectClock = true;
                    ProtectHostname = true;

                    # Syscalls einschränken
                    SystemCallArchitectures = "native";
                    SystemCallFilter = [ "@system-service" ];
                    SystemCallErrorNumber = "EPERM";

                    # Nur UNIX-Sockets erlauben (Docker & dein bind-Socket)
                    RestrictAddressFamilies = [
                      "AF_UNIX"
                      "AF_INET"
                      "AF_INET6"
                    ];

                    # Keine Caps nötig solange kein Low-Port TCP gebunden wird
                    CapabilityBoundingSet = [ ];
                    AmbientCapabilities = [ ];

                  };
                };
          };

          tmpfiles.rules = lh.lib.modules.mkJailTmpfiles {
            serviceName = "traefik";
            user = "traefik";
            group = "traefik";
            dataPaths = optionals (cfg.dataDir != null) [ "${cfg.dataDir}:${cfg.dataDir}" ];
          };
        };
        networking.firewall = {
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = [ 443 ];
        };
      }
    );
}
