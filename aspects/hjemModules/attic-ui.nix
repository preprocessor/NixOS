{
  tack.inputs.attic-ui = {
    url = "gh:kleinbem-dev/attic-ui";
    group = "nix";
  };

  modules.core =
    {
      inputs',
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.my.services.attic-ui;
    in
    {
      config = lib.mkIf cfg.enable {
        services.nginx.virtualHosts.${cfg.domain} = {
          enableACME = true;
          forceSSL = true;
          root = cfg.package;
          locations."/" = {
            tryFiles = "$uri $uri/ /200.html";
          };
        };
      };

      options.my.services.attic-ui = {
        enable = lib.mkEnableOption { };

        domain = lib.mkOption {
          type = lib.types.str;
        };

        settings = lib.mkOption {
          type = lib.types.json;
          default = { };
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.symlinkJoin {
            name = "attic-ui";
            paths = [
              inputs'.attic-ui.packages.attic-ui
              (pkgs.writeTextDir "config.json" (builtins.toJSON cfg.settings))
            ];
          };
        };
      };
    };
}
