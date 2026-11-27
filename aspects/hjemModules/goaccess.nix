{
  modules.core =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.goaccess;

      dataDir = "/var/lib/goaccess";
      logsDir = "/var/log/goaccess";

      ExecStart = pkgs.writeShellScript "goaccess-start" ''
        set -eu

        # nginx may not have created the new log yet right after a switch.
        i=0
        until [ -f ${cfg.logFile} ]; do
          i=$((i + 1))
          if [ "$i" -ge 30 ]; then
            echo "timed out waiting for ${cfg.logFile}" >&2
            exit 1
          fi
          sleep 1
        done

        args=(
          ${cfg.logFile}
          --log-format='%h %^[%d:%t %^] "%r" %s %b "%R" "%u" "%v"'
          --date-format='%d/%b/%Y'
          --time-format='%T'
          --real-time-html
          --addr=127.0.0.1
          --port=${toString cfg.port}
          --ws-url=wss://${cfg.domain}:443/ws
          --origin=https://${cfg.domain}
          --output=${dataDir}/index.html
          --db-path=${dataDir}/db
          --persist
          --keep-last=${toString cfg.keepLast}
          --html-refresh=30
          --geoip-database=${pkgs.dbip-city-lite.mmdb}
          --enable-panel=GEO_LOCATION
          --enable-panel=VIRTUAL_HOSTS
          --unknowns-log=${logsDir}/unknowns.log
          --invalid-requests=${logsDir}/invalid-requests.log
          --html-report-title="GoAccess - ${cfg.domain}"
        )

        # --restore requires an existing database.
        if [ -d ${dataDir}/db ] && [ -n "$(ls -A ${dataDir}/db)" ]; then
          args+=(--restore)
        fi

        exec ${cfg.package}/bin/goaccess "''${args[@]}"
      '';
    in
    {
      options.services.goaccess = {
        enable = lib.mkEnableOption "GoAccess real-time nginx traffic dashboard";

        package = lib.mkPackageOption pkgs "goaccess" { };

        userName = lib.mkOption {
          type = lib.types.str;
          default = "goaccess";
          description = "System user that runs GoAccess.";
        };

        domain = lib.mkOption {
          type = lib.types.str;
          default = "stats.wyspr.xyz";
          description = "Domain of the nginx virtual host serving the dashboard.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 7890;
          description = "Local port for the GoAccess WebSocket server.";
        };

        logFile = lib.mkOption {
          type = lib.types.path;
          default = "/var/log/nginx/access.log";
          description = "nginx access log to analyze.";
        };

        keepLast = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Number of days of data to keep.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ cfg.package ];

        users.groups.${cfg.userName} = { };
        users.users.${cfg.userName} = {
          isSystemUser = true;
          group = cfg.userName;
          extraGroups = [ config.services.nginx.group ];
        };

        systemd.services.goaccess = {
          description = "GoAccess real-time nginx traffic dashboard";
          wantedBy = [ "multi-user.target" ];
          after = [ "nginx.service" ];
          serviceConfig = {
            inherit ExecStart;
            Type = "simple";
            User = cfg.userName;
            Group = config.services.nginx.group;
            StateDirectory = [
              "goaccess"
              "goaccess/db"
            ];
            StateDirectoryMode = "0750";
            LogsDirectory = "goaccess";
            LogsDirectoryMode = "0750";
            UMask = "0027";
            Restart = "on-failure";
            RestartSec = 2;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            NoNewPrivileges = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            SystemCallFilter = "~@clock @cpu-emulation @debug @keyring @memlock @module @mount @obsolete @privileged @reboot @resources @setuid @swap @raw-io";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            ReadWritePaths = [ dataDir ];
          };
        };

        # Keep access.log as-is for fail2ban, and add a vhost-aware log for
        # GoAccess so the Virtual Hosts panel can compare subdomains.
        services.nginx.commonHttpConfig = ''
          log_format goaccess '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$host"';
          access_log /var/log/nginx/access.log combined;
          access_log /var/log/nginx/goaccess.log goaccess;
        '';

        services.nginx.virtualHosts.${cfg.domain} = {
          enableACME = true;
          forceSSL = true;
          root = dataDir;

          # Reachable through the SSH tunnel only: the tunnel lands on
          # 127.0.0.1, while public requests to the same vhost are denied.
          locations."/" = {
            tryFiles = "$uri $uri/ =404";
            extraConfig = ''
              allow 127.0.0.1;
              allow ::1;
              deny all;
            '';
          };
          locations."/ws" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              allow 127.0.0.1;
              allow ::1;
              deny all;
            '';
          };
        };
      };
    };
}
