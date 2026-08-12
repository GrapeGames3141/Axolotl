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

## Run and test

Use Godot 4.7.1 to import `project.godot`, or run:

```powershell
& 'E:\CodexCache\godot-android-4.7.1\godot\Godot_v4.7.1-stable_win64_console.exe' --path . --editor
& 'E:\CodexCache\godot-android-4.7.1\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . -s res://tests/test_runner.gd
```

Exports are configured in `export_presets.cfg`. Export output paths are `builds/` and intentionally ignored by Git. A debug setting named `debug/minigame_duration_override` can shorten minigames during automated testing; normal builds retain 30/45 seconds.

## Caveats

The prototype pairs generated storybook art with procedural fallback marks and brief synthesized feedback tones rather than recorded audio. Generated source intermediates are not required to run the project.
