#!/usr/bin/env python3
"""Make the dark and tinted appearances of an iOS app icon from its light 1024x1024 PNG.

The foreground subject is lifted with Apple's Vision framework (the same subject lifting as
Photos); everything behind it is turned into a night scene. Needs macOS 14+ and
pillow, numpy, pyobjc-framework-Vision, pyobjc-framework-Quartz (see SKILL.md for the venv).

Writes into --out: mask.png, AppIcon-Dark.png, AppIcon-Tinted.png, preview.png (light | dark |
tinted at full size, and each at 60 px). With --install <path/AppIcon.appiconset> it also copies
the two PNGs there and adds the dark and tinted entries to Contents.json.
"""
import argparse
import json
import os
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter


def hex_rgb(value):
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def floats(value):
    return np.array([float(v) for v in value.split(",")], dtype=np.float32)


def blurred(mask, radius):
    img = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    return (np.asarray(img.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255)[..., None]


def subject_mask(path, size):
    """Foreground mask from Vision, as floats in [0, 1] at the icon's size."""
    import Quartz
    import Vision
    from Foundation import NSURL

    url = NSURL.fileURLWithPath_(os.path.abspath(path))
    handler = Vision.VNImageRequestHandler.alloc().initWithURL_options_(url, None)
    request = Vision.VNGenerateForegroundInstanceMaskRequest.alloc().init()
    ok, error = handler.performRequests_error_([request], None)
    if not ok or not request.results():
        sys.exit(f"Vision found no subject: {error}")
    observation = request.results()[0]
    buffer, error = observation.generateScaledMaskForImageForInstances_fromRequestHandler_error_(
        observation.allInstances(), handler, None)
    if buffer is None:
        sys.exit(f"Vision could not build the mask: {error}")
    image = Quartz.CIImage.imageWithCVPixelBuffer_(buffer)
    out = os.path.join(tempfile.mkdtemp(), "mask.png")
    context = Quartz.CIContext.contextWithOptions_(None)
    ok, error = context.writePNGRepresentationOfImage_toURL_format_colorSpace_options_error_(
        image, NSURL.fileURLWithPath_(out), Quartz.kCIFormatL8,
        Quartz.CGColorSpaceCreateWithName(Quartz.kCGColorSpaceLinearGray), None, None)
    if not ok:
        sys.exit(f"Could not write the mask: {error}")
    mask = Image.open(out).convert("L").resize(size)
    return mask


def install(appiconset, out_dir):
    for name in ("AppIcon-Dark.png", "AppIcon-Tinted.png"):
        shutil.copy(os.path.join(out_dir, name), appiconset)
    path = os.path.join(appiconset, "Contents.json")
    with open(path) as f:
        contents = json.load(f)
    images = [i for i in contents["images"] if not i.get("appearances")]
    light = [i for i in images if i.get("size") == "1024x1024"]
    if len(light) != 1:
        sys.exit("Contents.json must have exactly one 1024x1024 image without appearances")
    for value, name in (("dark", "AppIcon-Dark.png"), ("tinted", "AppIcon-Tinted.png")):
        entry = {k: v for k, v in light[0].items() if k != "filename"}
        entry["appearances"] = [{"appearance": "luminosity", "value": value}]
        entry["filename"] = name
        images.append(dict(sorted(entry.items())))
    contents["images"] = images
    with open(path, "w") as f:
        # Xcode's own formatting: two-space indent, " : " separators.
        f.write(json.dumps(contents, indent=2, separators=(",", " : ")) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("icon", help="the light 1024x1024 icon PNG")
    p.add_argument("--out", required=True, help="output directory (outside the repo)")
    p.add_argument("--night", default="0.20,0.23,0.42", help="r,g,b multiplier for the scenery (default indigo)")
    p.add_argument("--desaturate", type=float, default=0.55, help="scenery saturation kept, 0..1")
    p.add_argument("--subject-dim", type=float, default=0.80, help="brightness kept on the subject, 0..1")
    p.add_argument("--erode", type=int, default=2, help="pixels the mask shrinks by, against light fringes")
    p.add_argument("--keep-hue", action="append", default=[], metavar="LO:HI",
                   help="keep saturated scenery colours with hue in LO..HI (0..1) — e.g. 0.10:0.17 for yellow stars")
    p.add_argument("--light", action="append", default=[], metavar="X0,Y0,X1,Y1:LO:HI:#RRGGBB",
                   help="inside the box, recolour hue LO..HI to the colour — e.g. a window that lights up")
    p.add_argument("--no-mask", action="store_true", help="no subject: darken the whole icon (flat logos)")
    p.add_argument("--install", metavar="APPICONSET", help="copy into this .appiconset and update Contents.json")
    a = p.parse_args()

    os.makedirs(a.out, exist_ok=True)
    src = Image.open(a.icon).convert("RGB")
    if src.size != (1024, 1024):
        sys.exit(f"expected 1024x1024, got {src.size}")
    s = np.asarray(src).astype(np.float32) / 255
    hsv = np.asarray(src.convert("HSV")).astype(np.float32) / 255
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]

    if a.no_mask:
        mask_img = Image.new("L", src.size, 255)
    else:
        mask_img = subject_mask(a.icon, src.size)
    mask_img.save(os.path.join(a.out, "mask.png"))
    if a.erode:
        mask_img = mask_img.filter(ImageFilter.MinFilter(2 * a.erode + 1))
    m = (np.asarray(mask_img.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255)[..., None]

    lum = (s @ np.array([0.299, 0.587, 0.114], dtype=np.float32))[..., None]
    night = (lum + (s - lum) * a.desaturate) * floats(a.night)

    for spec in a.keep_hue:
        lo, hi = (float(v) for v in spec.split(":"))
        keep = blurred((hue > lo) & (hue < hi) & (sat > 0.45) & (val > 0.6), 1.0)
        night = night * (1 - keep) + s * keep

    yy, xx = np.mgrid[0:1024, 0:1024]
    for spec in a.light:
        box, lo, hi, colour = spec.split(":")
        x0, y0, x1, y1 = (int(v) for v in box.split(","))
        region = (xx > x0) & (xx < x1) & (yy > y0) & (yy < y1) & (hue > float(lo)) & (hue < float(hi)) & (sat > 0.2)
        lit = blurred(region, 1.5)
        night = night * (1 - lit) + hex_rgb(colour) * lit

    subject = np.clip(s * a.subject_dim, 0, 1)
    if a.no_mask:
        dark = np.clip((lum + (s - lum) * a.desaturate) * a.subject_dim * 0.6, 0, 1)
    else:
        dark = subject * m + night * (1 - m)
    gray = np.clip((lum - 0.5) * 1.1 + 0.5, 0, 1)
    tinted = np.repeat(gray * m, 3, axis=2)

    images = {}
    for name, arr in (("AppIcon-Dark.png", dark), ("AppIcon-Tinted.png", tinted)):
        img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")
        img.save(os.path.join(a.out, name))
        images[name] = img

    row = [src, images["AppIcon-Dark.png"], images["AppIcon-Tinted.png"]]
    sheet = Image.new("RGB", (3 * 1024 + 4 * 24, 1024 + 60 + 3 * 24), (128, 128, 128))
    for i, img in enumerate(row):
        x = 24 + i * (1024 + 24)
        sheet.paste(img, (x, 24))
        sheet.paste(img.resize((60, 60), Image.LANCZOS), (x, 1024 + 48))
    sheet.save(os.path.join(a.out, "preview.png"))

    if a.install:
        install(a.install, a.out)
    print("\n".join(os.path.join(a.out, n) for n in ("mask.png", "AppIcon-Dark.png", "AppIcon-Tinted.png", "preview.png")))


if __name__ == "__main__":
    main()
