{
  modules.features.desktop = { pkgs, ... }: {
    hj.packages = [
      pkgs.inkscape
    ];
  };
}
