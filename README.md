# Pocket Paludarium

A self-contained portrait Godot 4.7 prototype: tend one friendly axolotl, decorate its glassy water world, shop with earned pearls, and play two gentle minigames.

## Controls

Mouse/touch: use the large action buttons. In Decorate, select an item and tap the tank to place it; tap placed decor to return it. In Bubble Pop, tap bubbles. In Food Catch, tap the desired horizontal position to steer.

## Included features

- Fullness, happiness, and water quality (0–100), with recoverable decay capped at eight offline hours.
- Food, cleaning, petting, pearl shop, equipment modifiers, cosmetics, normalized persistent decor placement, and immediate atomic JSON saves.
- Gentle Filter slows water decay; Pearl Bubbler adds happiness and visible bubbles.
- Bubble Pop (30 seconds) and Food Catch (45 seconds), deterministic reward tiers, settings for sound/reduced motion/large targets.
- Subtle procedural button/feed tones and rising Bubble Pop tones are synthesized at runtime when Sound is enabled; there are no external audio assets.
- Coordinated built-in ImageGen storybook assets: a gouache/watercolor paludarium backdrop, transparent axolotl swimmer, and mapped 3×3 décor atlas. Final project assets live in `assets/storybook/`; generation prompts and transparency QA are recorded in `assets/storybook/generation-notes.md`.

Living pet milestone: name Pip (or choose a new sanitized name), earn permanent bond through care and minigames, complete three daily wishes, and unlock curious, hide-peek, sleeping, and Kindred celebration poses. New eating, sleeping, and hide-peek storybook cutouts are integrated with procedural fallbacks. Saves use versioned `user://pocket_paludarium_v2.json` with atomic backup recovery; a v1 save migrates once while retaining the original v1 file as a rollback copy.

## Google Play

Release builds go to the Play **internal** track automatically on every push to
`master`. Setup, secrets, the AdMob banner, and the console checklist are in
[docs/PLAY_ANDROID.md](docs/PLAY_ANDROID.md); the listing copy and the generated
icon, feature graphic, and phone screenshots are in [store/](store/) —
see [store/LISTING.md](store/LISTING.md).

A single AdMob bottom banner is wired through `autoload/ad_bar_service.gd`. It
serves **Google's official test unit** until both `ADMOB_USE_TEST_UNITS` and the
AdMob secrets are switched over, so test builds can never generate invalid
traffic. The game shrinks its stage to reserve room for the bar, so no control
ever sits underneath it.

## Run and test

Use Godot 4.7.1 to import `project.godot`, or run:

```powershell
& 'E:\CodexCache\godot-android-4.7.1\godot\Godot_v4.7.1-stable_win64_console.exe' --path . --editor
& 'E:\CodexCache\godot-android-4.7.1\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . -s res://tests/test_runner.gd
```

Regenerate the store art after any visual change:

```bash
godot --path . --resolution 720x1280 tests/capture.tscn
python3 scripts/tools/generate_store_assets.py
```

Exports are configured in `export_presets.cfg` (`Android Play` builds the signed
Play AAB via `scripts/ci/godot-export-android.sh`). Export output paths are `builds/` and intentionally ignored by Git. A debug setting named `debug/minigame_duration_override` can shorten minigames during automated testing; normal builds retain 30/45 seconds.

## Caveats

The prototype pairs generated storybook art with procedural fallback marks and brief synthesized feedback tones rather than recorded audio. Generated source intermediates are not required to run the project.
