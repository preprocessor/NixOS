{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.remotePackages = lib.mkOption {
        type = with lib.types; lazyAttrsOf package;
        default = { };
      };

      config = {
        packages = config.remotePackages;

        apps.list-remote-packages = {
          type = "app";
          meta.description = "List packages that will be built remotely (to be used in a Github workflow)";
          program =
            (pkgs.writeShellScript "list-remote-packages" ''
              echo "${
                config.remotePackages
                |> lib.attrNames
                |> lib.concatLines
                |> lib.trim
              }"
            '').outPath;
        };
      };
    };
}
