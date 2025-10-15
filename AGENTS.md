# Repository Guidelines

## Project Structure & Module Organization
- `config/` holds the active ZMK configuration: `efogtech_trackball_0.conf` for firmware options, `efogtech_trackball_0.keymap` for bindings, and `west.yml` defining required modules.
- `boards/arm/efogtech_trackball_0/` contains board support files (device trees, pinmux, drivers, and default Kconfig) that describe the endgame trackball hardware.
- `build.yaml` drives the GitHub Actions matrix; keep it aligned with any local build permutations added under `config/`.
- `zephyr/module.yml` registers this repo as a west module so ZMK can pick up the configuration automatically.

## Build, Test, and Development Commands
- `west init -l config && west update` — bootstrap west with the local manifest and pull dependent modules (custom pointer drivers, auto-hold extensions, etc.).
- `west build -p -b efogtech_trackball_0 -- -DZMK_CONFIG=$PWD/config` — produce firmware; outputs land in `build/zephyr/zmk.uf2`.
- `west build ... --pristine` — add `--pristine` when switching branches or configs to avoid stale artifacts.
- `west flash` — flash the connected board; confirm UF2 drag-and-drop is disabled before running this.

## Coding Style & Naming Conventions
- Device tree and overlay files use two-space indentation, lowercase node names, and hyphenated labels (`pointer.dtsi`, `buttons.dtsi`).
- C sources such as `pinmux.c` follow Zephyr conventions: four-space indentation, `snake_case` functions, and static scope unless symbols must be exported.
- Keymap layers in `config/efogtech_trackball_0.keymap` stay under 80 characters per line; name combos descriptively (`combo_scroll_drag`).

## Testing Guidelines
- Every change must, at minimum, pass `west build -p -b efogtech_trackball_0 -- -DZMK_CONFIG=$PWD/config`; treat a clean build as the smoke test.
- When altering board files, add a second verification build with `-DSNIPPET=studio-rpc-usb-uart` to mirror CI coverage in `build.yaml`.
- Attach hardware notes to the PR when manual validation (pointer motion, scroll suppression, etc.) was performed.

## Commit & Pull Request Guidelines
- Follow the existing Conventional Commit style (`feat:`, `bugfix:`, `docs:`) as seen in `git log`.
- Commit subject lines stay under 72 characters; body should outline rationale and highlight affected subsystems (e.g., keymap vs. sensor driver).
- PRs must include a brief summary, testing notes, linked issues (if any), and updated screenshots or logs for Studio changes.
- Group related configuration tweaks into a single PR to keep firmware artifacts traceable.

## Configuration Tips
- Keep local overrides in `config/` and avoid editing upstream modules; vendor updates are pulled via `west update`.
- When experimenting, duplicate the keymap with a `_wip` suffix and exclude it from `build.yaml` until stabilized.
