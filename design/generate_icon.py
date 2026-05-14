#!/usr/bin/env python3
"""
Generate ripple's app icon as a 1024×1024 PNG.

Design — "Single Note":
  - Deep navy radial gradient field, slightly cool at center, darker at corners
  - Soft aqua inner glow (the memory of where the strike landed)
  - Three concentric rings, decreasing in opacity (the wave aging into stillness)
  - One dark stone-glass disc at center with a meniscus highlight
  - Subtle outer vignette

Rendered at 4x (4096) then downsampled to 1024 for crisp anti-aliasing
on the thin rings.
"""
from PIL import Image, ImageDraw, ImageFilter
import math

# ─── Tunables ─────────────────────────────────────────────────────────
FINAL_SIZE = 1024
SCALE = 4                              # supersample factor
SIZE = FINAL_SIZE * SCALE              # 4096

# Colors (sRGB) — pulled from ripple's palette
def rgba(r, g, b, a=255):
    return (r, g, b, a)

DEEP_BG      = rgba(5, 12, 22)         # outer corners — very dark
MID_BG       = rgba(11, 26, 46)        # ¾ way out
WARM_CENTER  = rgba(18, 42, 72)        # gradient center — slight warmth
INNER_GLOW   = rgba(74, 168, 192)      # aqua memory bloom

STONE_OUTER  = rgba(6, 22, 42)         # dark stone edge
STONE_MID    = rgba(14, 38, 62)
STONE_FACE   = rgba(28, 70, 100)       # main face
STONE_HIGH   = rgba(170, 215, 235)     # wet meniscus highlight
RING_AQUA    = rgba(140, 200, 220)     # ring color (alpha varied per-ring)

# Geometry — all at FINAL_SIZE scale, multiplied up
CENTER = SIZE // 2
STONE_R = int(0.175 * SIZE)            # stone radius ~180px at 1024 → distinct silhouette
RING_R = [
    int(0.245 * SIZE),                 # ring 1 — closest
    int(0.330 * SIZE),                 # ring 2 — furthest
]
RING_THICK = max(1, int(0.0035 * SIZE))  # ~3.5px@1024 — hairline
RING_ALPHA = [85, 38]                  # subtle — hint of motion, not chrome

# ─── Helpers ──────────────────────────────────────────────────────────

def radial_gradient(size, center, color_stops):
    """
    color_stops: list of (radius_frac, (r,g,b,a))
    Builds a pixel-by-pixel radial gradient. Simple but slow at 4096²;
    fine for icon-scale one-shot rendering.
    """
    img = Image.new("RGBA", (size, size), color_stops[-1][1])
    px = img.load()
    cx, cy = center
    max_r = math.hypot(cx, cy)
    # Pre-sort stops by radius
    stops = sorted(color_stops, key=lambda s: s[0])
    for y in range(size):
        dy = y - cy
        for x in range(size):
            dx = x - cx
            d = math.hypot(dx, dy) / max_r  # 0..1
            # find bracket
            for i in range(len(stops) - 1):
                r0, c0 = stops[i]
                r1, c1 = stops[i + 1]
                if d <= r1:
                    t = 0 if r1 == r0 else (d - r0) / (r1 - r0)
                    t = max(0, min(1, t))
                    r = int(c0[0] * (1 - t) + c1[0] * t)
                    g = int(c0[1] * (1 - t) + c1[1] * t)
                    b = int(c0[2] * (1 - t) + c1[2] * t)
                    a = int(c0[3] * (1 - t) + c1[3] * t)
                    px[x, y] = (r, g, b, a)
                    break
    return img


def draw_ring(img, center, radius, thickness, color):
    """Draw a hairline ring using outline mode — PIL handles the erase correctly."""
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = center
    bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
    draw.ellipse(bbox, outline=color, width=thickness)


def draw_stone(img, center, radius):
    """Stone-glass disc with radial highlight."""
    cx, cy = center
    # Body — composite a radial gradient disc
    stone_img = radial_gradient(
        radius * 2 + 4,
        (radius + 2, radius + 2),
        [
            (0.0,  STONE_FACE),
            (0.55, STONE_MID),
            (0.92, STONE_OUTER),
            (1.0,  rgba(8, 30, 55, 0)),  # fade to transparent at edge
        ],
    )
    # Crop to a circle via mask
    mask = Image.new("L", stone_img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, stone_img.size[0], stone_img.size[1]], fill=255)
    stone_img.putalpha(mask)
    img.alpha_composite(stone_img, (cx - radius - 2, cy - radius - 2))

    # Meniscus highlight — soft ellipse positioned upper-left of the sphere
    high_w = int(radius * 0.42)
    high_h = int(radius * 0.22)
    canvas_w = high_w * 3
    canvas_h = high_h * 3
    high_img = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(high_img)
    # Build with reduced opacity directly so blur fades smoothly
    hd.ellipse(
        [canvas_w // 2 - high_w, canvas_h // 2 - high_h,
         canvas_w // 2 + high_w, canvas_h // 2 + high_h],
        fill=(STONE_HIGH[0], STONE_HIGH[1], STONE_HIGH[2], 110),
    )
    high_img = high_img.filter(ImageFilter.GaussianBlur(radius=radius * 0.12))
    # Composite at upper-left of the stone — center the canvas at the highlight's target
    target_x = cx - int(radius * 0.30)
    target_y = cy - int(radius * 0.42)
    img.alpha_composite(high_img, (target_x - canvas_w // 2, target_y - canvas_h // 2))


def draw_inner_glow(img, center, radius_frac, alpha):
    """Soft aqua bloom around the stone — the memory of where it landed."""
    r = int(radius_frac * SIZE)
    glow_img = Image.new("RGBA", (r * 2, r * 2), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_img)
    gd.ellipse([0, 0, r * 2, r * 2], fill=(INNER_GLOW[0], INNER_GLOW[1], INNER_GLOW[2], alpha))
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(radius=r * 0.22))
    cx, cy = center
    img.alpha_composite(glow_img, (cx - r, cy - r))


# ─── Compose ──────────────────────────────────────────────────────────

print(f"rendering at {SIZE}x{SIZE} (supersample {SCALE}x)...")

# 1. Background field — radial gradient
bg = radial_gradient(
    SIZE,
    (CENTER, CENTER),
    [
        (0.0,  WARM_CENTER),
        (0.55, MID_BG),
        (1.0,  DEEP_BG),
    ],
)

# 2. Aqua inner glow — the "remembered strike" warmth (subtle)
draw_inner_glow(bg, (CENTER, CENTER), radius_frac=0.32, alpha=28)

# 3. Three rings — outer first so inner ones layer on top cleanly
for r, alpha in zip(reversed(RING_R), reversed(RING_ALPHA)):
    draw_ring(bg, (CENTER, CENTER), r, RING_THICK, (RING_AQUA[0], RING_AQUA[1], RING_AQUA[2], alpha))

# 4. The stone in the center
draw_stone(bg, (CENTER, CENTER), STONE_R)

# 5. Slight vignette — pull eye to center, darken corners
vig = Image.new("L", (SIZE, SIZE), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([SIZE * 0.12, SIZE * 0.12, SIZE * 0.88, SIZE * 0.88], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(radius=SIZE * 0.10))
black = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 60))
black.putalpha(vig.point(lambda v: 60 - int(v * 60 / 255)))
bg = Image.alpha_composite(bg, black)

# 6. Downsample to final size — Lanczos for crisp small-feature retention
final = bg.resize((FINAL_SIZE, FINAL_SIZE), Image.Resampling.LANCZOS)

# 7. Flatten alpha — App Store Connect rejects icons with transparency.
#    Composite onto the deep-bg color so the corners are opaque navy.
opaque = Image.new("RGB", (FINAL_SIZE, FINAL_SIZE), DEEP_BG[:3])
opaque.paste(final, (0, 0), final)

# Save into AppIcon.appiconset for iOS
out_path = "../Ripple/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"
opaque.save(out_path, "PNG", optimize=True)
print(f"saved → {out_path}")

# Also save a preview copy for the design folder
opaque.save("ripple-icon-1024.png", "PNG", optimize=True)
print("preview → design/ripple-icon-1024.png")

# Save scaled-down preview at 180px to verify small-size readability
opaque.resize((180, 180), Image.Resampling.LANCZOS).save("ripple-icon-180.png", "PNG", optimize=True)
opaque.resize((58, 58), Image.Resampling.LANCZOS).save("ripple-icon-58.png", "PNG", optimize=True)
print("small previews → 180px + 58px (Settings size)")
