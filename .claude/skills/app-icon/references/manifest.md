# Layer manifest

Inputs resolve relative to the manifest file. Package names must be simple names; no absolute local paths belong in committed manifests. The layer list is **back to front**; the helper reverses it for Composer's front-first group list. Each item becomes a depth group (maximum four).

```json
{
  "reference": "reference.png",
  "background": {
    "default": "extended-srgb:0.025,0.095,0.27,1",
    "dark": "extended-srgb:0.008,0.012,0.035,1",
    "tinted": "extended-srgb:0.02,0.02,0.02,1"
  },
  "dark": {"shadow_floor": 0.38, "threshold": 0.18, "range": 0.65},
  "layers": [
    {"name": "00-Background", "image": "background.png", "material": "fidelity"},
    {"name": "01-Subject", "image": "subject.png", "dark_image": "subject-dark.png", "mono_image": "subject-mono.png", "material": "fidelity"}
  ]
}
```

Each layer chooses exactly one source:

- `image`: prepared PNG or SVG, centered on the shared 1024 canvas. Supplied files are copied into the package. Prepared SVG needs explicit `dark_image` and `mono_image` when those appearances need distinct colors; otherwise native automatic appearance treatment applies. PNG gets auto-derived dark/mono variants when unspecified.
- `mask`: an ImageMagick draw primitive in 1024-square coordinates. It extracts original pixels through an alpha mask. `feather` (pixels, default 0) softens the edge. Example: `"mask": "circle 512,480 710,480", "feather": 12`. Use image-specific geometry; it is not automatic segmentation.
- `diffuse_background`: blur sigma for a reference-derived atmospheric plate. Only appropriate behind abstract shapes; it does not reconstruct missing objects.

`reference` is needed for mask/atmosphere extraction. It is center-cropped to square without stretching; inspect this crop before building. Source alpha is multiplied by the mask. Use a real opaque backdrop or native fill where appropriate.

`material` can be `native` (default: let Composer supply effects) or `fidelity` (verified low-effect settings for artwork whose lighting must remain visible). Dark compression preserves alpha and scales RGB by a smooth function of maximum RGB intensity. Optional per-layer `dark` overrides global `dark`; tune these values to the image. Grayscale conversion preserves alpha; supplied mono artwork gives better control for complex subjects.

`background` entries are Composer color strings. Defaults provide a neutral dark background, but choose colors that suit the reference. `supported_platforms` may override `{"squares":"shared"}`. The helper targets the 1024-square workflow; do not pretend it prepares watch artwork or tvOS/visionOS image stacks.

The helper writes `build-manifest.json` inside the output package with asset names, layer order, and material settings. The authoring manifest and source files should also stay in the repository outside the `.icon` package so future edits can rebuild it.

The concrete `sunrise-example.json` demonstrates this session's successful masks. It expects a sibling `reference.png`; the image is intentionally not bundled. It is an example for reproducing that composition, not a template for arbitrary pictures.
