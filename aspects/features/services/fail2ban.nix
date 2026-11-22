{
  modules.host.xyz = {
    services.openssh.settings.LogLevel = "VERBOSE";

    # Custom fail2ban filter for the GTM access log format.
    # Matches 400 (malformed/binary requests), 403 (denied by ACL), 404 (not
    # found), 444 (closed by the catch-all vhost above).
    # No journalmatch — forces file-based reading from the access log.
    environment.etc."fail2ban/filter.d/nginx-deny-gtm.conf".text = ''
      [Definition]
      failregex = ^<HOST> - \[.*?\] "[^"]*" (?:400|403|404|444) \d+
      ignoreregex =
      datepattern = ^[^\[]*\[({DATE})
    '';

    services.fail2ban = {
      enable = true;

      bantime = "24h";
      bantime-increment = {
        enable = true; # Enable increment of bantime after each violation
        multipliers = "2 4 8 16 32 64 128 256 512 1024 2048";
        overalljails = true; # Calculate the bantime based on all the violations
      };

      maxretry = 3;
      ignoreIP = [
        "127.0.0.0/8"
        "10.0.0.0/8"
        "192.168.0.0/16"
        "::1"
      ];

      jails = {
        sshd.settings = {
          maxretry = 5;
          findtime = 300;
          mode = "aggressive";
        };

        nginx-deny = ''
          enabled = true
          filter = nginx-deny-gtm
          logpath = /var/log/nginx/access.log
          maxretry = 5
          findtime = 60
          ignoreip = 127.0.0.0/8 ::1 10.0.10.0/24 192.168.0.0/24
        '';

        # Ban IPs that hit webhook rate limits (reads nginx error log from journal)
        nginx-ratelimit = ''
          enabled = true
          filter = nginx-limit-req
          backend = systemd
          maxretry = 10
          findtime = 60
          ignoreip = 127.0.0.0/8 ::1 10.0.10.0/24 192.168.0.0/24
        '';

        # apache-nohome-iptables = {
        #   settings = {
        #     # Block an IP address if it accesses a non-existent
        #     # home directory more than 5 times in 10 minutes,
        #     # since that indicates that it's scanning.
        #     filter = "apache-nohome";
        #     action = ''iptables-multiport[name=HTTP, port="http,https"]'';
        #     logpath = "/var/log/httpd/error_log*";
        #     backend = "auto";
        #     findtime = 600;
        #     bantime = 600;
        #     maxretry = 5;
        #   };
        # };

        dovecot = {
          settings = {
            # block IPs which failed to log-in
            # aggressive mode add blocking for aborted connections
            filter = "dovecot[mode=aggressive]";
            maxretry = 3;
          };
        };
      };
    };
  };
}
