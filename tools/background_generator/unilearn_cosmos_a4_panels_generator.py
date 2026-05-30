import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


# ============================================================
# OUTPUT SETTINGS
# ============================================================

OUTPUT_DIR = "unilearn_cosmos_a4_panels"

PANEL_COUNT = 16
DPI = 300

# A4 portrait at 300 DPI.
PAGE_WIDTH = 2480
PAGE_HEIGHT = 3508

SAVE_FULL_STRIP_PREVIEW = True
PREVIEW_SCALE = 0.08

SEED = 8142026


# ============================================================
# STYLE SETTINGS
# ============================================================

COLOR_A = np.array([0.0, 0.0, 0.0], dtype=np.float32)
COLOR_B = np.array([0.008, 0.018, 0.055], dtype=np.float32)
COLOR_C = np.array([0.025, 0.045, 0.11], dtype=np.float32)

TOTAL_WIDTH = PAGE_WIDTH * PANEL_COUNT
TOTAL_HEIGHT = PAGE_HEIGHT

# Smaller and fewer stars than v1, with anti-overlap placement.
STARS_PER_PAGE = 58
STAR_COUNT = PANEL_COUNT * STARS_PER_PAGE
STAR_MIN_RADIUS = 6.0
STAR_MAX_RADIUS = 20.0
BRIGHT_STAR_CHANCE = 0.12

# Hard spacing to avoid stacked/overlapping square stars.
STAR_PADDING = 16
PLACEMENT_ATTEMPTS_PER_STAR = 150
PAGE_EDGE_MARGIN = 40

# Keep dust off for a clean app-like look.
DUST_COUNT = 0

NEBULA_STRENGTH = 0.34
NEBULA_SCALE = 0.00135
NEBULA_DETAIL_SCALE = 0.0045


# ============================================================
# MATH HELPERS
# ============================================================

def smoothstep(edge0, edge1, x):
    x = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def lerp(a, b, t):
    return a * (1.0 - t) + b * t


def hash_noise(x, y, seed=0):
    return np.mod(np.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453123, 1.0)


def value_noise(x, y, seed=0):
    xi = np.floor(x)
    yi = np.floor(y)

    xf = x - xi
    yf = y - yi

    u = xf * xf * (3.0 - 2.0 * xf)
    v = yf * yf * (3.0 - 2.0 * yf)

    n00 = hash_noise(xi, yi, seed)
    n10 = hash_noise(xi + 1.0, yi, seed)
    n01 = hash_noise(xi, yi + 1.0, seed)
    n11 = hash_noise(xi + 1.0, yi + 1.0, seed)

    nx0 = lerp(n00, n10, u)
    nx1 = lerp(n01, n11, u)

    return lerp(nx0, nx1, v)


def fbm(x, y, seed=0, octaves=5):
    total = np.zeros_like(x, dtype=np.float32)
    amplitude = 0.5
    frequency = 1.0
    norm = 0.0

    for octave in range(octaves):
        total += value_noise(x * frequency, y * frequency, seed + octave * 19) * amplitude
        norm += amplitude
        amplitude *= 0.5
        frequency *= 2.0

    return total / max(norm, 0.0001)


# ============================================================
# BACKGROUND RENDERING
# ============================================================

def render_gradient_and_nebula(panel_index):
    x0 = panel_index * PAGE_WIDTH
    x1 = x0 + PAGE_WIDTH

    xs = np.linspace(x0, x1 - 1, PAGE_WIDTH, dtype=np.float32)
    ys = np.linspace(0, PAGE_HEIGHT - 1, PAGE_HEIGHT, dtype=np.float32)

    xx, yy = np.meshgrid(xs, ys)

    uv_x_global = xx / float(TOTAL_WIDTH)
    uv_y = yy / float(PAGE_HEIGHT)

    vertical = smoothstep(0.18, 1.0, uv_y)

    base = lerp(
        COLOR_A.reshape(1, 1, 3),
        COLOR_B.reshape(1, 1, 3),
        vertical.reshape(PAGE_HEIGHT, PAGE_WIDTH, 1),
    )

    glow = np.zeros((PAGE_HEIGHT, PAGE_WIDTH), dtype=np.float32)
    glow_centers = [
        (0.13, 0.28, 0.26, 0.18),
        (0.34, 0.68, 0.32, 0.15),
        (0.56, 0.38, 0.28, 0.17),
        (0.78, 0.74, 0.31, 0.13),
        (0.93, 0.30, 0.22, 0.12),
    ]

    for cx, cy, radius, power in glow_centers:
        dx = (uv_x_global - cx) / radius
        dy = (uv_y - cy) / (radius * 1.65)
        dist = np.sqrt(dx * dx + dy * dy)
        glow += smoothstep(1.0, 0.0, dist) * power

    nx = xx * NEBULA_SCALE
    ny = yy * NEBULA_SCALE

    nebula_main = fbm(nx, ny, SEED, octaves=5)
    nebula_detail = fbm(xx * NEBULA_DETAIL_SCALE, yy * NEBULA_DETAIL_SCALE, SEED + 99, octaves=3)

    nebula = nebula_main * 0.72 + nebula_detail * 0.28
    nebula = smoothstep(0.46, 0.88, nebula)
    nebula *= NEBULA_STRENGTH
    nebula *= 0.38 + vertical * 0.62

    combined_glow = np.clip(glow + nebula, 0.0, 1.0)

    color = lerp(
        base,
        COLOR_C.reshape(1, 1, 3),
        combined_glow.reshape(PAGE_HEIGHT, PAGE_WIDTH, 1),
    )

    strip_center_x = 0.5
    strip_center_y = 0.52
    dx = (uv_x_global - strip_center_x) / 0.78
    dy = (uv_y - strip_center_y) / 0.82
    vignette = np.clip(1.0 - (dx * dx + dy * dy) * 0.32, 0.55, 1.0)

    color *= vignette.reshape(PAGE_HEIGHT, PAGE_WIDTH, 1)

    img = np.clip(color * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGB")


# ============================================================
# STAR GENERATION
# ============================================================

def _boxes_overlap(a, b, padding=0):
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    return not (
        ax1 + padding < bx0 or
        bx1 + padding < ax0 or
        ay1 + padding < by0 or
        by1 + padding < ay0
    )


def generate_stars():
    rng = random.Random(SEED)
    stars = []

    for page in range(PANEL_COUNT):
        page_x0 = page * PAGE_WIDTH
        page_x1 = page_x0 + PAGE_WIDTH
        placed_boxes = []

        created = 0
        attempts = 0
        max_attempts = STARS_PER_PAGE * PLACEMENT_ATTEMPTS_PER_STAR

        while created < STARS_PER_PAGE and attempts < max_attempts:
            attempts += 1

            depth = rng.random()
            r = STAR_MIN_RADIUS + (STAR_MAX_RADIUS - STAR_MIN_RADIUS) * (depth ** 1.9)

            if rng.random() < BRIGHT_STAR_CHANCE:
                r *= rng.uniform(1.1, 1.35)

            r = int(round(r))
            x = rng.uniform(page_x0 + PAGE_EDGE_MARGIN + r, page_x1 - PAGE_EDGE_MARGIN - r)
            y = rng.uniform(PAGE_EDGE_MARGIN + r, PAGE_HEIGHT - PAGE_EDGE_MARGIN - r)

            box = (
                int(x - r),
                int(y - r),
                int(x + r),
                int(y + r),
            )

            overlap = False
            for existing in placed_boxes:
                if _boxes_overlap(box, existing, STAR_PADDING):
                    overlap = True
                    break

            if overlap:
                continue

            alpha = int(210 + 45 * rng.random())
            if rng.random() < BRIGHT_STAR_CHANCE:
                alpha = 255

            placed_boxes.append(box)
            stars.append((x, y, r, alpha))
            created += 1

    return stars


def draw_stars_on_panel(img, stars, panel_index):
    x0 = panel_index * PAGE_WIDTH
    x1 = x0 + PAGE_WIDTH

    overlay = Image.new("RGBA", (PAGE_WIDTH, PAGE_HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")

    # Crisp solid squares only. No side glow, no halo.
    for x, y, radius, alpha in stars:
        if x0 - radius <= x <= x1 + radius:
            px = int(round(x - x0))
            py = int(round(y))
            r = int(round(radius))

            draw.rectangle(
                (px - r, py - r, px + r, py + r),
                fill=(255, 255, 255, alpha),
            )

    img = img.convert("RGBA")
    img.alpha_composite(overlay)
    return img.convert("RGB")


# ============================================================
# EXPORT
# ============================================================

def export_panels():
    out = Path(OUTPUT_DIR)
    out.mkdir(parents=True, exist_ok=True)

    print("Generating global star map...")
    stars = generate_stars()

    preview_images = []

    for i in range(PANEL_COUNT):
        print(f"Rendering panel {i + 1:02d}/{PANEL_COUNT}...")

        img = render_gradient_and_nebula(i)
        img = draw_stars_on_panel(img, stars, i)

        filename = out / f"unilearn_cosmos_A4_panel_{i + 1:02d}.png"
        img.save(filename, dpi=(DPI, DPI), optimize=True)

        if SAVE_FULL_STRIP_PREVIEW:
            preview = img.resize(
                (
                    max(1, int(PAGE_WIDTH * PREVIEW_SCALE)),
                    max(1, int(PAGE_HEIGHT * PREVIEW_SCALE)),
                ),
                Image.Resampling.LANCZOS,
            )
            preview_images.append(preview)

    if SAVE_FULL_STRIP_PREVIEW and preview_images:
        preview_w = preview_images[0].width * PANEL_COUNT
        preview_h = preview_images[0].height

        strip = Image.new("RGB", (preview_w, preview_h), (0, 0, 0))
        x = 0
        for preview in preview_images:
            strip.paste(preview, (x, 0))
            x += preview.width

        strip.save(out / "unilearn_cosmos_full_row_preview.png", optimize=True)

    print()
    print("Done.")
    print(f"Output folder: {out.resolve()}")
    print(f"Each panel: {PAGE_WIDTH}x{PAGE_HEIGHT}px, A4 portrait, {DPI} DPI")
    print("Place panel_01 to panel_16 side by side with no gaps/margins.")


if __name__ == "__main__":
    export_panels()
