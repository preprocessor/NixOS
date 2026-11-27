{
  tack.inputs.mddog = {
    url = "gh:qu8n/mddog/issue-20-add-linux-support";
    group = "cli";
    type = "fetch";
    frozen = true;
    patches = [
      "https://gist.githubusercontent.com/onelocked/10889b2ce08bd001867958980ef05679/raw/b13c78ccbb9e69a402ae7f89fbb7b35bfeba9ff4/mddog-mardown-fix.patch"
    ];
  };

  perSystem = { pkgs, inputs, ... }: {
    remotePackages.mddog = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
      pname = inputs._meta.mddog.repo;
      version = inputs._meta.mddog.rev;
      src = inputs.mddog;
      cargoLock.lockFile = finalAttrs.src + "/Cargo.lock";
      doCheck = false;
    });
  };

  modules.core =
    {
      self',
      pkgs,
      config,
      lib,
      ...
    }:
    let
      mddSplit = pkgs.writeShellApplication {
        name = "yazi-mdd-split";
        runtimeInputs = [
          config.my.kitty.package
          self'.packages.mddog
          pkgs.util-linux
        ];
        text = ''
          if [ -z "''${MDD_SPLIT_DETACHED:-}" ]; then
            MDD_SPLIT_DETACHED=1 exec setsid -f "$0" "$@"
          fi
          exec </dev/null >/dev/null 2>&1
          win="''${KITTY_WINDOW_ID:?not running inside kitty}"
          [ -S /tmp/kitty ] && sock="unix:/tmp/kitty" || sock="''${KITTY_LISTEN_ON:?no kitty remote control socket}"
          k() { kitty @ --to "$sock" "$@"; }

          close() { k close-window --match="var:yazi_mdd=$win" >/dev/null 2>&1 || true; }

          case "''${1:-}" in
            open)
              close
              k launch \
                --next-to="id:$win" \
                --location=vsplit \
                --keep-focus \
                --var "yazi_mdd=$win" \
                -- mdd "$2"
              ;;
            close) close ;;
            *) echo "usage: $0 open <file> | close" >&2; exit 2 ;;
          esac
        '';
      };
    in
    {
      hj.packages = [
        self'.packages.mddog
        mddSplit
      ];
      my.yazi = {
        plugins = lib.mkAfter {
          mdd-split = pkgs.yaziPlugins.mkYaziPlugin {
            pname = "mdd-split";
            version = "local";
            src =
              pkgs.writeTextDir "main.lua" # lua
                ''
                  local M = {}

                  local current = nil

                  local hovered = ya.sync(function()
                    local h = cx.active.current.hovered
                    return h and tostring(h.url) or nil
                  end)

                  local preview_hidden = ya.sync(function() return rt.mgr.ratio[3] == 0 end)

                  local function markdown(url)
                    return url:match("%.md$") or url:match("%.markdown$") or url:match("%.mdx$")
                  end

                  local function preview(visible)
                    if preview_hidden() == visible then
                      ya.emit("plugin", { "toggle-pane", "min-preview" })
                    end
                  end

                  function M:setup()
                    ps.sub("hover", function()
                      local url = hovered()
                      if url and not markdown(url) then url = nil end
                      if url == current then return end
                      current = url

                      preview(url == nil)
                      ya.async(function() Command("yazi-mdd-split"):arg(url and { "open", url } or { "close" }):spawn() end)
                    end)
                  end

                  return M
                '';
          };
        };
        initLua =
          lib.mkAfter # lua
            ''
              require("mdd-split"):setup()
            '';
      };
    };
}
