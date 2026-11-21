{
  modules.core =
    { config, lib, ... }:
    lib.mkIf config.security.polkit.enable {
      security.polkit.extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (
            subject.isInGroup("wheel") &&
            [
              "org.freedesktop.login1.reboot",
              "org.freedesktop.login1.reboot-multiple-sessions",
              "org.freedesktop.login1.power-off",
              "org.freedesktop.login1.power-off-multiple-sessions",
            ].indexOf(action.id) !== -1
          ) {
            return polkit.Result.YES;
          }
        });
      '';
    };

  modules.features.desktop = { pkgs, ... }: {
    security.polkit.enable = true;

    systemd.user.services.polkit-agent = {
      description = "PolicyKit Authentication by Gnome";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    my.hyprland.windowrules.polkit = [
      {
        match.class = "^polkit-gnome-authentication-agent-1$";
        rules = {
          pin = true;
          float = true;
          center = true;
          no_close_for = true;
        };
      }
    ];
  };
}
