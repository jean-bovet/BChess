---
name: app-icon
description: Create or refine a layered Apple Icon Composer app icon from a reference image or existing light icon, with dark, tinted, and clear appearance previews. Use for Apple app icon and appearance work, not ordinary image editing or unrelated icon systems.
---

# /app-icon — reference-faithful layered Apple icons

Deliver a reference-faithful `.icon` document, reusable source inputs and layer manifest, and previews rendered by Apple's Icon Composer. Work in the requesting repository's established location; read its root AGENTS.md and follow its worktree rules. Do not commit, publish, or change app targets unless requested. No simulator is needed for rendering.

## This repo

- Icon set: `Shared/Assets.xcassets/AppIcon.appiconset`, shared by both apps
  (`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` on both targets in `project.yml`): one universal iOS
  1024×1024 `AppIcon-iOS-1024.png` (a knight on a chessboard) with its `AppIcon-Dark.png` and
  `AppIcon-Tinted.png` variants, and the Mac sizes `AppIcon-mac-16.png` … `AppIcon-mac-1024.png`
  (from the same artwork; no dark or tinted variant). The Mac App Store needs the 1024 px Mac icon.
- Targets: `BChess (iOS)` (iPhone and iPad, iOS 18) and `BChess (macOS)` (macOS 15).
- No layered `.icon` document or manifest yet; integration route: the asset catalog until a reviewed
  `.icon` replaces it, added to both app targets through `project.yml` (then `xcodegen generate`,
  committing the project with it). The current Dark and Tinted PNGs came from the earlier
  Vision-based appearance script (no longer shipped); it used the defaults (Vision lifted the knight;
  the board turned to night).

## Inspect and choose an approach

View the supplied reference and existing icon. If no separate reference is supplied, use the existing light icon as the reference. An appearance-only request does not by itself authorize migrating a target from an asset catalog to a `.icon` document; prepare the reviewed artwork first and follow the repo's integration route. Normalize raster references to a project-local PNG when using the extraction helper. Identify the actual background, foreground shapes, occlusion order, colors, and glow. For a non-square reference, choose the crop deliberately and show it if important content would be lost. Use a common unmasked 1024-square canvas for iPhone/iPad/Mac. Adapt platform settings and canvas when the request targets watchOS; bundled scripts are for square platforms.

Prefer SVG/native design layers for simple geometric artwork. For richly shaded, glowing, or AI-generated references where fidelity matters, derive PNG layers from the actual pixels using soft masks, or generate/edit missing regions through an available native image generation tool. Do not replace detailed artwork with a simplified vector approximation without making that design choice clear. Do not use chroma-key extraction for an image that never had a solid key background.

Use up to four meaningful depth groups. Choose masks and feathering for this image; **do not reuse the sunrise example's circles or curves on unrelated images**. Include glows in the owning layer's bounds. Preserve identical geometry across appearances. Deriving layers from a flattened picture is approximate: it cannot recover hidden original artwork. A blurred atmospheric plate can fill hidden areas for an abstract icon, but cannot serve as semantic inpainting for a face, object, or text. Supply a repaired background and de-occluded layers when needed. Check the composite for seams and duplicated shapes.

For AI work, use available native image generation and inspect every result. Do not claim a local CLI flag guarantees backend access, billing, or tools. If a CLI is requested, inspect its installed help/features and attach the reference using `-i <path> -- <prompt>`; the `--` prevents the image option consuming the prompt. Keep the original unchanged. Do not silently use a billed API fallback.

## Build the document

Read [references/manifest.md](references/manifest.md) when preparing inputs. Write a per-icon manifest that describes back-to-front layer order, masks or prepared image paths, appearance colors, and material treatment. Keep it with a project-relative source image or prepared layers so the build is portable. The bundled helper uses Python's standard library and ImageMagick:

```sh
python3 <skill-dir>/scripts/build_icon.py --manifest icon-inputs/layers.json --output icon-output/AppIcon.icon
python3 <skill-dir>/scripts/render_icon.py --icon icon-output/AppIcon.icon --output icon-output/previews --platform iOS
```

Output directories must be new. Iterate in sibling directories instead of overwriting an existing project icon. `build_icon.py` accepts source-derived PNG layers and prepared PNG/SVG layers, preserves alpha, and records all package assets. It does not analyze or segment an image itself.

For clean shapes, use native material effects and let Composer handle background, blur, highlights, and masking. For a close match to artwork with intrinsic glow, retaining that glow and using `material: fidelity` is a deliberate compromise: it suppresses added blur, specular highlights, shadows, and translucency that can cause double outlines. Offer the reference-faithful result first when matching is the user's priority.

Set default and dark appearances deliberately; the helper's configurable shadow compression is a starting point, not a universal palette. Tinted layers must be neutral grayscale with readable tonal hierarchy. Adjust grayscale contrast or provide explicit mono artwork if conversion loses the subject. No rounded canvas corners belong in source layers.

## Render and review

Discover `ictool` from selected Xcode or a standalone Icon Composer installation. Its flags and the programmatic `icon.json` schema can change; the helper uses a format verified with Xcode 27. Inspect installed help and validate by rendering, rather than claiming JSON construction alone proves compatibility. If rendering fails, diagnose a missing tool, sandbox restriction, or metadata format once, then correct the specific issue or report the blocker. Do not substitute a flattened preview and call it Apple's rendering.

Render Default, Dark, TintedLight, TintedDark, ClearLight, and ClearDark. Inspect the contact sheet and default/dark at useful sizes. Check fidelity, alpha edges, order, tinted contrast, cropping, and doubled highlights. Apple applies the final mask, so preview exports have rounded corners even though artwork layers do not. Re-render after visual or metadata changes. State which platform was checked; don't imply real-device or App Store validation.

Deliver the `.icon` package, previews, inputs, and repeatable manifest/commands. If integrating is requested, add the document to the correct Xcode target and set its App Icon name to the document basename. A matching `.icon` supersedes the legacy asset catalog; Xcode creates older-OS fallbacks from it. Preserve an existing icon until the replacement is reviewed. Cleanup only explicitly requested or known temporary outputs, and retain the current build's dependencies.

Official guidance: [Icon Composer](https://developer.apple.com/icon-composer/) and [creating an icon](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer). Check current guidance when platform or tool behavior matters.
