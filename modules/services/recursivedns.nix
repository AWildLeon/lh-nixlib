{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.lh.services.recursivedns = {
    enable = lib.mkEnableOption "DNS services (unbound + dnsdist)";
  };

  config = lib.mkIf config.lh.services.recursivedns.enable {
    systemd.services.unbound.serviceConfig = {
      LimitNOFILE = 131072;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
      RestrictSUIDSGID = true;
      RestrictNamespaces = true;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };

    # Generate unbound cookie secret on boot
    systemd.services.unbound-cookie-generator = {
      description = "Generate Unbound Cookie Secret";
      wantedBy = [ "multi-user.target" ];
      before = [ "unbound.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/unbound";
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.openssl}/bin/openssl rand -hex 16 > /var/lib/unbound/cookie-secret'";
        User = "unbound";
        Group = "unbound";
      };
    };

    # Disable conflicting DNS services
    services = {
      resolved.enable = false;
      nscd.enableNsncd = false;
      unbound = {
        enable = true;
        resolveLocalQueries = false; # Disable local resolution to avoid conflicts with DNSdist
        settings.server = {
          interface = [
            "127.0.0.1@5300"
            "::1@5300"
          ];
          #   interface-automatic = false;

          do-ip6 = true;
          prefer-ip6 = true;

          #   # Sicherheit
          qname-minimisation = true;
          harden-referral-path = true;
          harden-algo-downgrade = true;
          aggressive-nsec = true;
          hide-identity = true;
          hide-version = true;
          minimal-responses = true;
          cookie-secret-file = "/var/lib/unbound/cookie-secret";

          #   # DNSSEC
          #   # auto-trust-anchor-file = "/var/lib/unbound/root.key";
          val-clean-additional = true;

          #   # # Anti-Amplification
          edns-buffer-size = 1232;
          msg-buffer-size = 4096;
          #   # ip-ratelimit = 200;
          #   # ratelimit = 1000;

          #   # 0x20 / Cookies
          use-caps-for-id = true;

          #   # Cache/Performance
          prefetch = true;
          prefetch-key = true;
          msg-cache-size = "256m";
          rrset-cache-size = "512m";
          cache-max-ttl = 86400;
          cache-min-ttl = 10;

          num-threads = 4;
          so-reuseport = true;
        };
      };
      dnsdist = {
        enable = true;
        listenPort = 5353;
        extraConfig = ''
          -- Backends
          newServer("127.0.0.1:5300")


          -- Listener (klassisch Do53)
          addLocal("[::]:53", { reusePort=true })
          addLocal("0.0.0.0:53", { reusePort=true })


          -- EDNS / Fragmentation
          -- setMaxUDPOutstanding(65535)
          -- setPayloadSizeOnSelfGeneratedAnswers(1232)   -- vermeiden von IP-Fragmenten

          -- ACL - Access Control
          setACL({"0.0.0.0/0", "::/0"})    -- Public; ggf. einschränken

          -- Create netmask group for bypass network
          bypassNMG = newNMG()

          -- Bypass for AS213579
          bypassNMG:addMask("2a14:47c0:e000::/40")

          -- Bypass Rule
          addAction(NetmaskGroupRule(bypassNMG), AllowAction())

          -- Rate limiting: alles was NICHT in bypassNMG ist und >50 QPS hat, droppen
          addAction(
            AndRule{MaxQPSIPRule(50, 32, 64) },
            DropAction()
          )



          -- Block malicious query types
          addAction(QTypeRule(DNSQType.ANY), SpoofRawAction("\007rfc\056\052\056\050\000", { typeForAny=DNSQType.HINFO }))
          addAction(QNameRule("version.bind"), DropAction())     -- Hide version info
          addAction(QNameRule("hostname.bind"), DropAction())    -- Hide hostname

          -- Connection limits
          setMaxTCPClientThreads(256)
          setMaxTCPQueuedConnections(1000)

          -- Routing Policy
          setServerPolicy(roundrobin)  -- Better load distribution than firstAvailable

          -- Packet Cache
          pc = newPacketCache(500000, {maxTTL=3600, minTTL=0})
          getPool(""):setCache(pc)
        '';
      };
    };
  };
}
