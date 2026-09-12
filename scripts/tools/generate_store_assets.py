#!/usr/bin/env python3
"""Generate the Google Play listing art for Pocket Paludarium.

Everything is composed from the committed storybook art in assets/storybook/
plus real in-game captures, so the listing always matches the shipped build.

Outputs
  assets/generated/app_icon_432.png          launcher / adaptive foreground
  assets/generated/app_icon_background.png   adaptive background layer
  store/play_icon_512.png                    Play Console app icon (512x512)
  store/feature_graphic_1024x500.png         Play Console feature graphic
  store/phone/NN_name.png                    phone screenshots (1080x1920)

Captures come from tests/capture.tscn; refresh them with

    godot --path . --resolution 720x1280 tests/capture.tscn

then re-run this script (it reads them from the Godot user:// directory, or
from --captures if you pass a path).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
STORYBOOK = ROOT / "assets" / "storybook"
GENERATED = ROOT / "assets" / "generated"
STORE = ROOT / "store"

SERIF_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANS_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

DEEP = (14, 32, 38)
CREAM = (255, 244, 214)
MINT = (198, 236, 222)

# Screenshot name -> caption shown in the framed Play screenshot.
SHOTS = [
    ("named-home", "Tend one gentle axolotl"),
    ("eating", "Feed, clean, and pet for pearls"),
    ("wishes", "Three little wishes every day"),
    ("sleeping", "Cozy decor to rest beneath"),
    ("hide-peek", "A pet with moods of its own"),
    ("kindred", "Grow a permanent bond"),
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def find_captures(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    candidates = list(
        Path.home().glob("**/app_userdata/Pocket Paludarium/captures")
    )
    if not candidates:
        sys.exit(
            "No captures found. Run:\n"
            "  godot --path . --resolution 720x1280 tests/capture.tscn\n"
            "or pass --captures <dir>."
        )
    return max(candidates, key=lambda p: p.stat().st_mtime)


def water_backdrop(size: tuple[int, int], zoom: float = 1.0) -> Image.Image:
    """Cover-crop the paludarium backdrop to the requested size."""
    src = Image.open(STORYBOOK / "paludarium-backdrop-v1.png").convert("RGB")
    w, h = size
    scale = max(w / src.width, h / src.height) * zoom
    resized = src.resize(
        (round(src.width * scale), round(src.height * scale)), Image.LANCZOS
    )
    left = (resized.width - w) // 2
    top = int((resized.height - h) * 0.45)
    return resized.crop((left, top, left + w, top + h))


def axolotl(height: int, source: str = "axolotl-swim-v1.png") -> Image.Image:
    art = Image.open(STORYBOOK / source).convert("RGBA")
    art = art.crop(art.getbbox())
    scale = height / art.height
    return art.resize(
        (round(art.width * scale), round(art.height * scale)), Image.LANCZOS
    )


def drop_shadow(layer: Image.Image, blur: int, offset: tuple[int, int], alpha: int):
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, alpha), (0, 0), layer.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, offset)
    out.alpha_composite(layer)
    return out


def radial_glow(size: tuple[int, int], center, radius: int, color, strength: int):
    glow = Image.new("L", size, 0)
    d = ImageDraw.Draw(glow)
    d.ellipse(
        [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
        fill=strength,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius // 2))
    tint = Image.new("RGBA", size, color + (0,))
    tint.putalpha(glow)
    return tint


def build_icon() -> Image.Image:
    """Square icon art at 1024, downscaled by callers."""
    s = 1024
    img = water_backdrop((s, s), zoom=1.35).convert("RGBA")
    # Deepen the edges so the round-masked launcher icon reads as a pond.
    vignette = Image.new("L", (s, s), 0)
    ImageDraw.Draw(vignette).ellipse([-s * 0.15, -s * 0.15, s * 1.15, s * 1.15], fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(s // 8))
    dark = Image.new("RGBA", (s, s), DEEP + (255,))
    dark.putalpha(Image.eval(vignette, lambda v: 235 - v))
    img.alpha_composite(dark)
    img.alpha_composite(radial_glow((s, s), (s // 2, int(s * 0.58)), int(s * 0.34), MINT, 120))

    # Keep the pet inside the adaptive-icon safe zone (the launcher mask can
    # crop up to ~33% of each edge), so the same art works masked or square.
    pet = axolotl(int(s * 0.38))
    pet = drop_shadow(pet, 26, (0, 20), 130)
    img.alpha_composite(pet, ((s - pet.width) // 2, int(s * 0.36)))
    return img


def build_feature_graphic() -> Image.Image:
    w, h = 1024, 500
    img = water_backdrop((w, h), zoom=1.15).convert("RGBA")
    img.alpha_composite(radial_glow((w, h), (int(w * 0.72), int(h * 0.6)), 300, MINT, 110))

    # Readability scrim behind the title, heaviest on the left.
    scrim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(scrim)
    for x in range(w):
        a = int(215 * max(0.0, 1.0 - (x / (w * 0.68)) ** 1.4))
        sd.line([(x, 0), (x, h)], fill=DEEP + (a,))
    img.alpha_composite(scrim)

    pet = axolotl(262)
    pet = drop_shadow(pet, 30, (0, 18), 140)
    img.alpha_composite(pet, (w - pet.width - 8, int(h * 0.38)))

    d = ImageDraw.Draw(img)
    d.text((66, 128), "Pocket", font=font(SERIF_BOLD, 82), fill=CREAM)
    d.text((66, 218), "Paludarium", font=font(SERIF_BOLD, 82), fill=CREAM)
    d.text(
        (70, 328),
        "A calm axolotl to care for",
        font=font(SANS, 34),
        fill=MINT,
    )
    return img.convert("RGB")


def frame_screenshot(shot: Image.Image, caption: str) -> Image.Image:
    """1080x1920 Play screenshot: the capture, plus a caption band."""
    w, h = 1080, 1920
    img = water_backdrop((w, h), zoom=1.3).convert("RGBA")
    img.alpha_composite(Image.new("RGBA", (w, h), DEEP + (170,)))

    caption_band = 210
    inner_w = w - 96
    inner_h = h - caption_band - 96
    scale = min(inner_w / shot.width, inner_h / shot.height)
    view = shot.convert("RGBA").resize(
        (round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS
    )

    # Rounded device-ish frame.
    radius = 46
    plate = Image.new("RGBA", (view.width + 16, view.height + 16), (0, 0, 0, 0))
    ImageDraw.Draw(plate).rounded_rectangle(
        [0, 0, plate.width - 1, plate.height - 1], radius + 8, fill=(255, 255, 255, 46)
    )
    mask = Image.new("L", view.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, view.width - 1, view.height - 1], radius, fill=255)
    view.putalpha(mask)
    plate.alpha_composite(view, (8, 8))
    plate = drop_shadow(plate, 34, (0, 16), 150)

    x = (w - plate.width) // 2
    y = caption_band + (inner_h - plate.height) // 2 + 40
    img.alpha_composite(plate, (x, y))

    d = ImageDraw.Draw(img)
    f = font(SANS_BOLD, 54)
    tw = d.textbbox((0, 0), caption, font=f)[2]
    d.text(((w - tw) // 2, 92), caption, font=f, fill=CREAM)
    return img.convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", help="Directory holding the capture PNGs")
    args = parser.parse_args()

    GENERATED.mkdir(parents=True, exist_ok=True)
    (STORE / "phone").mkdir(parents=True, exist_ok=True)

    icon = build_icon()
    icon.resize((512, 512), Image.LANCZOS).convert("RGB").save(STORE / "play_icon_512.png")
    icon.resize((432, 432), Image.LANCZOS).save(GENERATED / "app_icon_432.png")
    # Adaptive background: the pond without the pet, so the mask can crop it.
    background = water_backdrop((432, 432), zoom=1.6).convert("RGBA")
    background.save(GENERATED / "app_icon_background.png")
    print(f"icon      -> {STORE / 'play_icon_512.png'}")

    feature = build_feature_graphic()
    feature.save(STORE / "feature_graphic_1024x500.png")
    print(f"feature   -> {STORE / 'feature_graphic_1024x500.png'}")

    captures = find_captures(args.captures)
    print(f"captures  <- {captures}")
    for index, (name, caption) in enumerate(SHOTS, start=1):
        src = captures / f"{name}.png"
        if not src.exists():
            print(f"  skip {name}: missing capture", file=sys.stderr)
            continue
        out = STORE / "phone" / f"{index:02d}_{name.replace('-', '_')}.png"
        frame_screenshot(Image.open(src), caption).save(out)
        print(f"  shot    -> {out}")


if __name__ == "__main__":
    main()
