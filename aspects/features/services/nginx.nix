{
  modules.host.xyz = { pkgs, ... }: {
    services.nginx = {
      enable = true;
      package = pkgs.nginxStable.overrideAttrs {
        version = "1.30.7";
        src = pkgs.fetchurl {
          url = "https://nginx.org/download/nginx-1.30.7.tar.gz";
          hash = "sha256-JWW1yDcFDpWPcPsPc8SOK8pFQq00n9NW9G+wxyYQvG4=";
        };
      };
      clientMaxBodySize = "0";
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      virtualHosts = {
        # Catch-all for requests that name no vhost: a bare IP, an unknown Host
        # header, or an SNI nothing here serves. Without this nginx answers such
        # requests with the alphabetically-first server block.
        # TLS handshakes for unknown names are rejected before
        # a certificate is sent, and plain-HTTP requests get 444 (connection
        # closed, no response). fail2ban's nginx-deny jail below counts 444s.
        "catch-all" = {
          serverName = "_";
          default = true;
          rejectSSL = true;
          extraConfig = ''
            return 444;
          '';
        };
      };
    };

    security.acme.defaults.email = "wyspr+acme@wyspr.xyz";
    security.acme.acceptTerms = true;

    networking.enableIPv6 = false;
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
