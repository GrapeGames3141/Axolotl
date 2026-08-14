# Storybook visual pass

Mode: built-in `image_gen` (one call per distinct asset; targeted second calls only for the chroma-key corrections). Transparent assets were generated on flat chroma backgrounds and processed with `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` using the E:-hosted Blender Python plus an E:-staged Pillow dependency.

## Final assets

| Asset | Dimensions / mode | SHA-256 | QA |
| --- | --- | --- | --- |
| `paludarium-backdrop-v1.png` | 941×1672 RGB | `4EDF48DA5E5C272497474034AA368FDC8FF0541E5C508C226C5335FDDF8C6046` | Portrait composition; painterly water, open center, dark UI margins. |
| `axolotl-swim-v1.png` | 1402×1122 RGBA | `6668E9981172CDA861C95E95B47ECEBBE313343547D8A0C8E4E60280A8B99D2F` | Transparent corner alpha 0, alpha extrema 0–255; soft gill edges and no visible green fringe. |
| `decor-atlas-v1.png` | 1254×1254 RGBA | `25324A3B03B85B30727C64B3414C63963D0D9774AF73B46A88B3D9E4647CF33D` | Transparent corner alpha 0, alpha extrema 0–255; trustworthy 3×3 atlas mapping after chroma removal. |

## Living pet pose pass

Mode: built-in `image_gen`, one reference-guided background-extraction call per pose using `axolotl-swim-v1.png`. Every source used a perfectly flat `#00ff00` background and was copied immediately to E staging before the same soft-matte/despill helper pass. Final outputs: `axolotl-eat-v1.png` (1402x1122 RGBA, SHA-256 `02206D88060058844CEDEE36F3A8A3DE6C9999AA82DDF885AAC0831573B1D0AA`), `axolotl-sleep-v1.png` (1254x1254 RGBA, SHA-256 `88804971535B3BC15F0961C73F916FE68684AAC48A338D05CFADED887150ED8A`), and `axolotl-peek-v1.png` (1402x1122 RGBA, SHA-256 `2C7ED5D78F72D2D4C8CA244C4B1A58537FD6044683D24AA2223A7950190E6775`). Each has transparent corners, alpha extrema 0-255, and no visible green fringe on visual inspection.

Prompts: eating: `identity-matched leucistic blush pink axolotl, coral gills, dark eyes, full body leaning forward with a small open anticipatory mouth, no food`; sleeping: `identity-matched leucistic axolotl gently curled, eyes closed, restful full silhouette`; hide peek: `identity-matched low compact front-half axolotl pose, suitable behind a hide`. All specified gouache/storybook styling, generous padding, no scenery, shadow, text, watermark, or green subject.

Original C: paths (under the existing imagegen session) are `exec-dea55ccf-8001-4929-a986-ff8365c36dc8.png`, `exec-0e7f05c2-52c2-4d96-8280-07080ee271aa.png`, and `exec-7b3476f1-acd8-4cb3-a319-630d6d04da6a.png`. Source and copied E-staging SHA-256 values matched: `74F252505B7767C315CD447D1C40A943DABBBB701560E7356E5E203FC60FCB7F`, `FA4C44147DAAE029775B7DAE3E332592E1283B85D4E07BC59E1A7792500B2727`, and `6CC860A120B98E76C87671D9161AA2E03719126D5B475B8ADD65F90DAB9F4850` respectively.

## Final prompts

### Backdrop

`Use case: stylized-concept. Asset type: portrait mobile-game paludarium backdrop. Opaque production game background for Pocket Paludarium: cozy glass paludarium with clear turquoise water, sandy gravel, rounded river stones, moss, delicate aquatic plants, pale driftwood hide, subtle surface reflections; no animal or UI. Soft hand-painted children's storybook gouache and watercolor, gentle painterly edges. Portrait 9:16 with open central water for axolotl and darker breathing room at top, bottom, and sides for UI. Warm sun glow, deep teal vignette. No text, logo, watermark, hard vector outlines, border, or clutter.`

### Axolotl cutout (corrected chroma pass)

`Use case: background-extraction. Cute friendly leucistic axolotl: blush pink body, coral feathery external gills, tiny dark eyes, gentle smile, full relaxed three-quarter swimming pose, tail visible, centered with generous padding, storybook gouache/watercolor. Entire background is exact flat uninterrupted #00ff00 edge-to-edge; no other background color, gradient, vignette, scenery, water, ground, shadow, reflection, haze, or glow. No green in subject, no text/logo/watermark.`

### Decor atlas (corrected chroma pass)

`Use case: background-extraction. Strict 3×3 Pocket Paludarium atlas: row 1 water fern, moon stone, cozy hollow log; row 2 cloud ceramic hide, aquarium filter, pearl bubbler; row 3 berry bites bowl, moss pellets bowl, coral ribbon hat. Consistent storybook gouache/watercolor craft style, evenly spaced, one fully visible object per cell. Entire background exact flat #ff00ff edge-to-edge; no black, white, texture, gradient, shadows, reflections, grid lines, labels, text, logo, watermark, or magenta in objects.`

## Source-to-final trail

Built-in originals were created under `C:\Users\Tak\.codex\generated_images\019ff794-e574-7b81-aeb2-b930a6cc586c\`: backdrop `exec-31061345-7e3e-4440-887a-43249c46b5af.png`, selected axolotl correction `exec-63aa7743-0ecb-4236-a7e3-756e23a9a712.png`, selected atlas correction `exec-80ae0da5-d4ce-4485-a361-6414d5e4a8c6.png`. Each selected original was copied to E: staging `tmp/imagegen/`, SHA-256 checked against its C: source, then copied/processed into these final assets. The final repo references only the E: assets above.
