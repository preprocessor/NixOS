{
  modules.host.xyz =
    {
      constants,
      pkgs,
      ...
    }:
    {
      services.openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          PermitEmptyPasswords = false;
          KbdInteractiveAuthentication = false;
        };
      };

      users.users.${constants.username}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB090gyVUFUA85M9cAjah1Me0juj+ZvfKjr8WZqrSAjm"
      ];

      security.sudo = {
        enable = true;
        extraRules = [
          {
            users = [ constants.username ];
            commands = [
              {
                command = "${pkgs.systemd}/bin/systemctl reboot";
                options = [ "NOPASSWD" ];
              }
              {
                command = "${pkgs.systemd}/bin/reboot";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };
    };

  modules.host.ramiel = {
    # Let the non-root SSH client bind local 443 for the tunnel.
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

    # Resolve the dashboard to the local end of the tunnel.
    networking.extraHosts = "127.0.0.1 stats.wyspr.xyz";

    my.openssh.settings.Host = {
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };

      "goaccess" = {
        HostName = "xyz.wyspr.xyz";
        User = "wyspr";
        LocalForward = [ "443 127.0.0.1:443" ];
        ExitOnForwardFailure = "yes";
        ServerAliveInterval = 30;
      };
    };
  };
}
