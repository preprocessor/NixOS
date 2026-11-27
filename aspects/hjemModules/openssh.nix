{
  modules.core =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.openssh;

      leaf =
        with lib.types;
        oneOf [
          str
          int
          bool
        ];

      # Recursive freeform type: blocks are nested attrsets all the way down,
      # ending in leaves.
      value =
        with lib.types;
        oneOf [
          leaf
          (listOf leaf)
          (attrsOf value)
        ];

      renderValue = v: if lib.isBool v then (if v then "yes" else "no") else toString v;

      # SSH uses the first value it finds, so exact Host blocks must come
      # before globs; the catch-all `*` goes last.
      patternRank =
        p:
        if p == "*" then
          2
        else if lib.hasInfix "*" p || lib.hasInfix "?" p then
          1
        else
          0;

      sortedPatterns =
        patterns:
        lib.sort (
          a: b:
          let
            ra = patternRank a;
            rb = patternRank b;
          in
          ra < rb || (ra == rb && a < b)
        ) (lib.attrNames patterns);

      renderOptions =
        indent: options:
        lib.concatMapStringsSep "\n" (
          name:
          let
            v = options.${name};
          in
          if lib.isAttrs v then
            throw "my.openssh.settings: nested attribute set at option '${name}' is not supported"
          else if lib.isList v then
            lib.concatMapStringsSep "\n" (item: "${indent}${name} ${renderValue item}") v
          else
            "${indent}${name} ${renderValue v}"
        ) (lib.attrNames options);

      renderBlock =
        keyword: patterns:
        lib.concatMapStringsSep "\n\n" (
          pattern: "${keyword} ${pattern}\n${renderOptions "  " patterns.${pattern}}"
        ) (sortedPatterns patterns);

      renderSettings =
        settings:
        lib.concatMapStringsSep "\n\n" (
          keyword:
          if lib.isAttrs settings.${keyword} then
            renderBlock keyword settings.${keyword}
          else
            throw "my.openssh.settings: '${keyword}' must be an attribute set of patterns"
        ) (lib.attrNames settings)
        + "\n";
    in
    {
      config = lib.mkIf (cfg.settings != { }) {
        hj.files.".ssh/config".text = renderSettings cfg.settings;
      };

      options.my.openssh.settings = lib.mkOption {
        type = lib.types.attrsOf value;
        default = { };
        example = lib.literalExpression ''
          {
            Host = {
              "*" = {
                AddKeysToAgent = "yes";
                IdentityFile = [ "~/.ssh/id_ed25519" ];
                ServerAliveInterval = 60;
              };
              "github.com" = {
                HostName = "github.com";
                User = "git";
                IdentityFile = "~/.ssh/id_ed25519";
                IdentitiesOnly = "yes";
              };
            };
            Match = {
              "host *.example.com" = {
                ForwardAgent = "yes";
              };
            };
          }
        '';
        description = ''
          Nested attribute set describing `ssh_config` blocks.

          - The first level is the block keyword, such as `Host` or `Match`.
          - The second level is the block pattern, such as `*`, `github.com`,
            or `host *.example.com`.
          - The leaves are option/value pairs. A list repeats the option,
            which is useful for directives like `IdentityFile`.

          Values are rendered as strings; booleans become `yes`/`no` and
          integers are rendered in decimal.

          Exact patterns are emitted before glob patterns, and `*` is emitted
          last, so specific `Host` blocks win over catch-all ones.
        '';
      };
    };
}
