{
  modules.host.xyz =
    { config, pkgs, ... }:
    {
      my.services.attic-ui = {
        enable = true;

        domain = "attic.wyspr.xyz";

        settings = {
          subtitle = "wyspr's Nix Binary Cache";
          footer = "wyspr.xyz";
          defaultEndpoint = "https://cache.wyspr.xyz";
          defaultCache = "main";
          upstreamFallback = true;
          publicKeys.main = "main:Rz328YhW+fhUPvBBhMyJyaF6XVOTh5oAzMKr0RO3ySQ=";
          specs."Cache" = "Attic";
          presets = [
            {
              label = "cache.wyspr.xyz";
              endpoint = "https://cache.wyspr.xyz";
              cacheName = "main";
            }
            {
              label = "cache.nixos.org";
              endpoint = "https://cache.nixos.org";
              cacheName = "";
            }
          ];
        };
      };

      services.atticd = {
        enable = true;
        environmentFile = config.sops.templates."atticd.env".path;
        settings = {
          listen = "127.0.0.1:8080";
          "allowed-hosts" = [ "cache.wyspr.xyz" ];
          "api-endpoint" = "https://cache.wyspr.xyz/";
          "garbage-collection" = {
            interval = "12 hours";
            "default-retention-period" = "30 days";
          };
        };
      };

      sops.templates."atticd.env".content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder.attic_rs256_secret}
      '';

      environment.systemPackages = [ pkgs.attic-client ];
    };

  modules.features.desktop = {
    nix.settings = {
      trusted-substituters = [ "https://cache.wyspr.xyz/main" ];
      extra-trusted-public-keys = [ "main:Rz328YhW+fhUPvBBhMyJyaF6XVOTh5oAzMKr0RO3ySQ=" ];
    };
  };
}
