{
  modules.core = { lib, ... }: {
    # Enable NetworkManager
    networking.networkmanager.enable = lib.mkDefault true;

    boot = {
      kernelModules = [ "tcp_bbr" ];
      kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr";
      kernel.sysctl."net.core.default_qdisc" = "cake";
    };

    networking.nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  modules.host.xyz = {
    networking = {
      useDHCP = false;

      defaultGateway = "147.93.176.1";

      interfaces."eth0".useDHCP = false;

      interfaces."eth0".ipv4.addresses = [
        {
          address = "147.93.189.239";
          prefixLength = 20;
        }
      ];
    };
  };
}
