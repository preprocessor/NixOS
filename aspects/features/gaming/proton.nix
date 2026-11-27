{
  modules.features.gaming = { self', ... }: {
    programs.steam.extraCompatPackages = with self'.packages; [
      proton-cachyos
      proton-ge
    ];
  };
}
