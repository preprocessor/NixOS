{
  tack.inputs.forgejo-terminal-theme = {
    url = "git+https://codeberg.org/ivanhercaz/forgejo-terminal-theme.git";
    type = "fetch";
    frozen = true;
  };

  tack.shorturls.xyz = "git+https://git.wyspr.xyz/preprocessor/{path}";

  modules.host.xyz =
    {
      inputs,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.forgejo;
    in
    {
      services.forgejo = {
        enable = true;
        user = "git";
        group = "git";
        stateDir = "/var/lib/forgejo";
        database.type = "sqlite3";
        settings = {
          ui = {
            DEFAULT_THEME = "terminal";
            THEMES = "forgejo-auto, forgejo-light, forgejo-dark, terminal";
          };
          time.DEFAULT_UI_LOCATION = config.time.timeZone;
          server = {
            DOMAIN = "git.wyspr.xyz";
            ROOT_URL = "https://git.wyspr.xyz/";
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = 3000;
            START_SSH_SERVER = false;
            SSH_DOMAIN = "git.wyspr.xyz";
            SSH_PORT = 22;
            SSH_USER = "git";
            SSH_ROOT_PATH = "/var/lib/forgejo/.ssh";
            LANDING_PAGE = "/preprocessor?tab=repositories";
          };
          repository.DISABLE_STARS = true;
          service.DISABLE_REGISTRATION = true;
          session.COOKIE_SECURE = true;
          other = {
            SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
            SHOW_FOOTER_POWERED_BY = false;
            SHOW_FOOTER_VERSION = false;
          };
        };
      };

      services.nginx.virtualHosts.${cfg.settings.server.DOMAIN} = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${cfg.settings.server.HTTP_ADDR}:${toString cfg.settings.server.HTTP_PORT}";
          proxyWebsockets = true;
        };
      };

      users.groups.git = { };
      users.users.git = {
        isSystemUser = true;
        group = "git";
        home = cfg.stateDir;
        useDefaultShell = true;
      };

      environment.systemPackages = [ cfg.package ];

      systemd.tmpfiles.settings."forgejo-files" =
        let
          icon = pkgs.fetchurl {
            url = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.svg";
            sha256 = "sha256-EIClQw7bYnjcA+SwTvwWyL7VuUNAjWSK1yGiiDaBQiA=";
          };

          dirs = [
            "${cfg.customDir}"
            "${cfg.customDir}/public"
            "${cfg.customDir}/public/assets"
            "${cfg.customDir}/public/assets/css"
            "${cfg.customDir}/public/assets/img"
            "${cfg.customDir}/templates"
            "${cfg.customDir}/templates/custom"
          ];

          files = [
            {
              src = "${inputs.forgejo-terminal-theme}/theme-terminal.css";
              dest = "${cfg.customDir}/public/assets/css/theme-terminal.css";
            }
            {
              src = "${inputs.forgejo-terminal-theme}/footer.tmpl";
              dest = "${cfg.customDir}/templates/custom/footer.tmpl";
            }
            {
              src = "${icon}";
              dest = "${cfg.customDir}/public/assets/img/logo.svg";
            }
            {
              src = "${icon}";
              dest = "${cfg.customDir}/public/assets/img/favicon.svg";
            }
          ];
        in
        (lib.genAttrs dirs (_: {
          d = {
            inherit (cfg) user group;
            mode = "0750";
          };
        }))
        // (
          files
          |> map ({ src, dest }: lib.nameValuePair dest { "L+".argument = src; })
          |> builtins.listToAttrs
        );
    };
}
