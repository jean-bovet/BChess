---
name: app-icon-appearances
description: Give the iOS app icon its Dark and Tinted appearances (iOS 18+ Home Screen) from the existing light 1024×1024 PNG — lift the subject with Apple's Vision, turn the scenery behind it into night, make a grayscale tinted version, add both to the AppIcon set and check that the asset catalog compiles them. Use when Jean asks for a dark-mode or tinted app icon, or after the light icon changes.
---

# /app-icon-appearances — dark and tinted app icon from the light one

The light icon stays the source of truth. `scripts/icon_appearances.py` derives the other two:

- **Dark**: Vision's subject lifting (the same as Photos) cuts out the foreground; everything behind
  it is desaturated and multiplied toward indigo, so the scenery becomes a night version of itself.
  The subject is dimmed slightly (`--subject-dim`) so light areas do not glare.
- **Tinted**: the subject in grayscale on black; iOS colours it with the user's tint.

Both are opaque 1024×1024 PNGs, like the light one. This is the asset-catalog route (no `.icon`
file, no project change). Icon Composer layers (Liquid Glass) are a separate, hand-made job.


## This repo

- Icon set: `Shared/Assets.xcassets/AppIcon.appiconset` (the iOS 1024×1024 `AppIcon-iOS-1024.png` next to the Mac sizes, which get no dark or tinted variant).
- Flags that gave the committed result: the defaults (Vision lifts the knight; the board turns to night).
- Minimum deployment target: iOS 18.

## Steps

1. **Tools**, in a venv outside the repo (the scratchpad), never in the repo:
   ```sh
   python3 -m venv "$SCRATCH/icon-venv"
   "$SCRATCH/icon-venv/bin/pip" install -q pillow numpy pyobjc-framework-Vision pyobjc-framework-Quartz
   ```
2. **Look at the light icon** (Read the PNG). Note what should stay bright at night (stars, lamps,
   a moon) and which box holds a window or light worth switching on, in 1024-px coordinates.
   A flat logo with no scenery: use `--no-mask` (the whole icon is darkened instead).
3. **Generate** into the scratchpad, not the repo:
   ```sh
   "$SCRATCH/icon-venv/bin/python" -I .claude/skills/app-icon-appearances/scripts/icon_appearances.py \
     <icon set>/AppIcon.png --out "$SCRATCH/icon" [flags]
   ```
   Read `mask.png` (white = what Vision kept) and `preview.png` (light | dark | tinted, with 60-px
   thumbnails). Iterate on the flags: `--night r,g,b` (sky colour), `--desaturate`,
   `--subject-dim`, `--erode` (raise it if a light fringe shows around the subject),
   `--keep-hue LO:HI` (hue 0..1: ~0.0 red, 0.08 orange, 0.13 yellow, 0.33 green, 0.55 sky blue),
   `--light X0,Y0,X1,Y1:LO:HI:#RRGGBB`. If the mask misses part of the subject or grabs scenery,
   say so: the fix is art, not flags.
4. **Show Jean** `preview.png` and wait for his go.
5. **Install**: rerun with the same flags plus
   `--install <icon set>`. It copies `AppIcon-Dark.png` and
   `AppIcon-Tinted.png` and adds the `luminosity` `dark` / `tinted` entries to `Contents.json`
   (Xcode's formatting). Already present? Delete the two old entries from `Contents.json` first.
6. **Verify**, without a simulator:
   ```sh
   xcrun actool <asset catalog> --compile "$SCRATCH/actool" --platform iphoneos \
     --minimum-deployment-target <iOS target> --app-icon AppIcon \
     --output-partial-info-plist "$SCRATCH/actool/info.plist" --output-format human-readable-text
   xcrun assetutil --info "$SCRATCH/actool/Assets.car" | grep -c '"Appearance" : "UIAppearanceDark"'
   xcrun assetutil --info "$SCRATCH/actool/Assets.car" | grep -c '"Appearance" : "ISAppearanceTintable"'
   ```
   No warnings from `actool`, and both counts above zero. Seeing it on a Home Screen
   (long-press → Edit → Customize → Dark / Tinted) is Jean's check on his phone.
7. **Commit** the icon set when Jean asks (assets only; the flags used go in the message).
