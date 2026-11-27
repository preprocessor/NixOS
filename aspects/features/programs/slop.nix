{
  modules.host.ramiel = { wrapPackage, pkgs, ... }: {
    hj.packages = with pkgs; [
      worktrunk
      (wrapPackage {
        package = opencode;
        runtimePackages = [
          nodejs
        ];
      })
      pi-coding-agent
    ];
  };
}
