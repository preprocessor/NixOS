{
  tack.inputs.wxyz.url = "xyz:wxyz";

  modules.host.xyz = { packages', ... }: {
    services.nginx.virtualHosts."wyspr.xyz" = {
      enableACME = true;
      forceSSL = true;
      root = packages'.wxyz;
      locations."/" = {
        tryFiles = "$uri $uri/ =404";
      };
    };

    services.nginx.virtualHosts."www.wyspr.xyz" = {
      enableACME = true;
      forceSSL = true;
      globalRedirect = "wyspr.xyz";
    };
  };
}
