# attic-ui service on attic.wyspr.xyz

## Intent / why

The `xyz` host runs an Attic cache (`atticd`) behind nginx at `cache.wyspr.xyz` with a
single `main` cache. There is no browser UI for inspecting it. `attic-ui` is a static
SvelteKit SPA that queries Attic's HTTP API and renders cache/store-path metadata. This
change deploys that UI at `attic.wyspr.xyz` and pre-wires it to the existing cache.

## Goals

- Serve the `attic-ui` static SPA at `https://attic.wyspr.xyz` on the `xyz` host.
- Bake a runtime `config.json` so the UI defaults to `https://cache.wyspr.xyz`, cache
  `main`, and the existing public key, instead of auto-detecting the wrong origin.
- Pin the SPA as a tack flake input so its version is locked and reviewable.
- Match existing vhost conventions: ACME, forceSSL, IPv4 firewall already open.

## Non-goals / anti-goals

- No changes to `atticd` itself, the cache token, git/Jellyfin/etc. services, or DNS
  records (DNS is handled outside this repo).
- No mutable state on disk, no systemd service for the UI (it is purely static).
- Do not add it to `remotePackages` / CI cache warming in this change.

## Constraints

- `aspects/features/services/nginx.nix` and several other service files have
  uncommitted work; only targeted additions are made to `nginx.nix`, preserving the
  existing content.
- Package outputs are read-only; `config.json` cannot be written into `$out`.
- tack inputs are declared in Nix via `config.tack.inputs.<name>`, then written to
  `.tack/pins.toml` / `.tack/pins.lock.json` by `nix run .#write-tack` (which invokes
  `tack update`). The generated files were not hand-authored. Note: `write-tack`
  dropped the pre-existing `forgejo-terminal-theme` pin because it was never declared
  in Nix; that pin was restored verbatim in both generated files so Forgejo's theme
  keeps resolving.

## Approaches

Two ways to get `config.json` into the browser were considered:

- **A — Merged docroot derivation (chosen):** symlink the SPA package plus a generated
  `config.json` into one immutable store path; point nginx `root` at it. Stateless,
  declarative, config served as an ordinary asset.
- **B — nginx inline override:** serve the package path as `root` and intercept
  `/config.json` with a `location` block. Less Nix glue but relies on nginx location
  matching and makes the config a special case.

Chosen A.

## Decisions (builder's calls, not user-specified)

- tack input declared with `config.tack.inputs.attic-ui` in `nginx.nix` (the consuming
  module, matching how `disko` is declared in `xyz/disks.nix`):
  `url = "gh:kleinbem-dev/attic-ui"`, group `nix` so it shares the pinned nixpkgs via
  `all_follow`. `nix run .#write-tack` generated `pins.toml` and the lock entry.
- Consume via `inputs'.attic-ui.packages.attic-ui`.
- `config.json` contents: `defaultEndpoint = https://cache.wyspr.xyz`,
  `defaultCache = main`, `upstreamFallback = true`, `publicKeys.main =
  "main:Rz328YhW+fhUPvBBhMyJyaF6XVOTh5oAzMKr0RO3ySQ="`, plus a small `presets` list
  (this cache + `cache.nixos.org`) and a subtitle/footer bearing the wyspr.xyz name.
- Vhost `attic.wyspr.xyz` added to `nginx.nix` alongside the existing vhosts:
  `enableACME`, `forceSSL`, `root` = merged docroot,
  `tryFiles = "$uri $uri/ /200.html"` for SPA fallback (SvelteKit adapter-static's
  fallback document). No extra firewall changes
  (80/443 already allowed).

## Files touched

- `aspects/features/services/nginx.nix` — `config.tack.inputs.attic-ui` declaration,
  merged docroot derivation, and the `attic.wyspr.xyz` virtualHost.
- `.tack/pins.toml` — generated input declaration.
- `.tack/pins.lock.json` — generated lock entry (plus restored Forgejo pin).
- `docs/superpowers/specs/2026-11-22-attic-ui-service-design.md` — this doc.

## Left to the builder (plan will cover)

1. Add the tack pin and generate/commit the lock entry.
2. Create the service module.
3. Verify: flake eval, NixOS config eval, nginx config, and a build of the docroot.
