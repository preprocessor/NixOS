{
  tack.inputs.melosso = {
    url = "gh:melosso/forgejo-theme-melosso";
    type = "fetch";
    frozen = true;
  };

  modules.host.xyz =
    {
      inputs,
      config,
      pkgs,
      ...
    }:
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

      users.groups.git = { };
      users.users.git = {
        isSystemUser = true;
        group = "git";
        home = "/var/lib/forgejo";
        useDefaultShell = true;
      };

      environment.systemPackages = [ config.services.forgejo.package ];

      systemd.tmpfiles.rules =
        let
          cfg = config.services.forgejo;
          icon = pkgs.fetchurl {
            url = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.svg";
            sha256 = "sha256-EIClQw7bYnjcA+SwTvwWyL7VuUNAjWSK1yGiiDaBQiA=";
          };
        in
        [
          "d '${cfg.customDir}' 0750 ${cfg.user} ${cfg.group} - -"
          "d '${cfg.customDir}/public' 0750 ${cfg.user} ${cfg.group} - -"
          "d '${cfg.customDir}/public/assets' 0750 ${cfg.user} ${cfg.group} - -"
          "d '${cfg.customDir}/public/assets/css' 0750 ${cfg.user} ${cfg.group} - -"
          "d '${cfg.customDir}/public/assets/img' 0750 ${cfg.user} ${cfg.group} - -"
          "d '${cfg.customDir}/templates' 0750 ${cfg.user} ${cfg.group} - -"
          "d '${cfg.customDir}/templates/custom' 0750 ${cfg.user} ${cfg.group} - -"

          "L+ '${cfg.customDir}/public/assets/css/theme-terminal.css' - - - - ${inputs.forgejo-terminal-theme}/theme-terminal.css"
          "L+ '${cfg.customDir}/templates/custom/footer.tmpl' - - - - ${inputs.forgejo-terminal-theme}/footer.tmpl"
          "L+ '${cfg.customDir}/public/assets/img/logo.svg' - - - - ${icon}"
          "L+ '${cfg.customDir}/public/assets/img/favicon.svg' - - - - ${icon}"
        ];
    };
}
