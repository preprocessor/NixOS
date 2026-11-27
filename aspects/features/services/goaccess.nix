{
  modules.host.xyz = {
    services.goaccess = {
      enable = true;
      logFile = "/var/log/nginx/goaccess.log";
    };
  };
}
