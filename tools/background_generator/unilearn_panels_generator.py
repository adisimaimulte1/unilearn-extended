import os
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


# ============================================================
# OUTPUT SETTINGS
# ============================================================

OUTPUT_DIR = "unilearn_cosmos_10_slides"
PANEL_FILENAME = "unilearn_cosmos_slide_{:02d}.png"
PREVIEW_FILENAME = "unilearn_cosmos_10_slides_preview.jpg"

DPI = 300

SLIDE_COUNT = 10
PAGE_WIDTH = 1920
PAGE_HEIGHT = 1080

TOTAL_WIDTH = PAGE_WIDTH * SLIDE_COUNT
TOTAL_HEIGHT = PAGE_HEIGHT

SEED = 8142026


# ============================================================
# STYLE SETTINGS
# ============================================================

COLOR_A = np.array([0.0, 0.0, 0.0], dtype=np.float32)
COLOR_B = np.array([0.008, 0.018, 0.055], dtype=np.float32)
COLOR_C = np.array([0.025, 0.045, 0.11], dtype=np.float32)

# Maintains roughly the same star density as the original
# 1920 x 3240 image with 260 stars.
STAR_COUNT = 870
STAR_MIN_RADIUS = 2.0
STAR_MAX_RADIUS = 7.0
BRIGHT_STAR_CHANCE = 0.10

STAR_PADDING = 6
PLACEMENT_ATTEMPTS_PER_STAR = 220
PANORAMA_EDGE_MARGIN = 40

NEBULA_STRENGTH = 0.34
NEBULA_SCALE = 0.00135
NEBULA_DETAIL_SCALE = 0.0045

# Global glow positions across the ten-slide journey.
# x, y, radius_x, strength
GLOW_CENTERS = [
    (0.045, 0.25, 0.055, 0.14),
    (0.145, 0.72, 0.070, 0.12),
    (0.255, 0.34, 0.075, 0.16),
    (0.365, 0.70, 0.070, 0.14),
    (0.485, 0.45, 0.085, 0.18),
    (0.605, 0.76, 0.070, 0.13),
    (0.715, 0.28, 0.075, 0.16),
    (0.825, 0.64, 0.080, 0.18),
    (0.915, 0.40, 0.075, 0.20),
    (0.982, 0.52, 0.055, 0.24),
]


# ============================================================
# MATH HELPERS
# ============================================================

def smoothstep(edge0, edge1, x):
    x = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def lerp(a, b, t):
    return a * (1.0 - t) + b * t


def hash_noise(x, y, seed=0):
    return np.mod(
        np.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453123,
        1.0,
    )


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
        total += (
            value_noise(x * frequency, y * frequency, seed + octave * 19)
            * amplitude
        )
        norm += amplitude
        amplitude *= 0.5
        frequency *= 2.0

    return total / max(norm, 0.0001)


# ============================================================
# BACKGROUND RENDERING
# ============================================================

def render_gradient_and_nebula(panel_index):
    """Render one slide using coordinates from the full panorama."""
    global_x_start = panel_index * PAGE_WIDTH

    xs = np.arange(
        global_x_start,
        global_x_start + PAGE_WIDTH,
        dtype=np.float32,
    )
    ys = np.arange(PAGE_HEIGHT, dtype=np.float32)
    xx, yy = np.meshgrid(xs, ys)

    uv_x = xx / float(TOTAL_WIDTH - 1)
    uv_y = yy / float(TOTAL_HEIGHT - 1)

    # A slight left-to-right evolution gives the presentation a journey,
    # while the vertical gradient preserves the documentation's look.
    vertical = smoothstep(0.10, 1.0, uv_y)
    journey = smoothstep(0.0, 1.0, uv_x)
    base_mix = np.clip(vertical * 0.72 + journey * 0.28, 0.0, 1.0)

    base = lerp(
        COLOR_A.reshape(1, 1, 3),
        COLOR_B.reshape(1, 1, 3),
        base_mix.reshape(PAGE_HEIGHT, PAGE_WIDTH, 1),
    )

    glow = np.zeros((PAGE_HEIGHT, PAGE_WIDTH), dtype=np.float32)

    for cx, cy, radius_x, power in GLOW_CENTERS:
        dx = (uv_x - cx) / radius_x
        dy = (uv_y - cy) / 0.38
        dist = np.sqrt(dx * dx + dy * dy)
        glow += smoothstep(1.0, 0.0, dist) * power

    nebula_main = fbm(
        xx * NEBULA_SCALE,
        yy * NEBULA_SCALE,
        SEED,
        octaves=5,
    )
    nebula_detail = fbm(
        xx * NEBULA_DETAIL_SCALE,
        yy * NEBULA_DETAIL_SCALE,
        SEED + 99,
        octaves=3,
    )

    nebula = nebula_main * 0.72 + nebula_detail * 0.28
    nebula = smoothstep(0.46, 0.88, nebula)
    nebula *= NEBULA_STRENGTH
    nebula *= 0.50 + vertical * 0.50

    combined_glow = np.clip(glow + nebula, 0.0, 1.0)

    color = lerp(
        base,
        COLOR_C.reshape(1, 1, 3),
        combined_glow.reshape(PAGE_HEIGHT, PAGE_WIDTH, 1),
    )

    # One vignette over the entire panorama. There is deliberately no
    # per-slide vignette, so adjacent panels meet without visible seams.
    panorama_dx = (uv_x - 0.5) / 0.80
    vertical_dy = (uv_y - 0.52) / 0.92
    vignette = np.clip(
        1.0 - (panorama_dx * panorama_dx + vertical_dy * vertical_dy) * 0.18,
        0.68,
        1.0,
    )
    color *= vignette.reshape(PAGE_HEIGHT, PAGE_WIDTH, 1)

    image_array = np.clip(color * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(image_array, "RGB")


# ============================================================
# STAR GENERATION
# ============================================================

def _boxes_overlap(a, b, padding=0):
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    return not (
        ax1 + padding < bx0
        or bx1 + padding < ax0
        or ay1 + padding < by0
        or by1 + padding < ay0
    )


def generate_stars():
    """Generate stars once in full-panorama coordinates."""
    rng = random.Random(SEED)
    stars = []
    placed_boxes = []

    created = 0
    attempts = 0
    max_attempts = STAR_COUNT * PLACEMENT_ATTEMPTS_PER_STAR

    while created < STAR_COUNT and attempts < max_attempts:
        attempts += 1

        depth = rng.random()
        radius = STAR_MIN_RADIUS + (
            STAR_MAX_RADIUS - STAR_MIN_RADIUS
        ) * (depth ** 2.4)

        if rng.random() < BRIGHT_STAR_CHANCE:
            radius *= rng.uniform(1.1, 1.3)

        radius = int(round(radius))
        x = rng.uniform(
            PANORAMA_EDGE_MARGIN + radius,
            TOTAL_WIDTH - PANORAMA_EDGE_MARGIN - radius,
        )
        y = rng.uniform(
            PANORAMA_EDGE_MARGIN + radius,
            PAGE_HEIGHT - PANORAMA_EDGE_MARGIN - radius,
        )

        box = (
            int(x - radius),
            int(y - radius),
            int(x + radius),
            int(y + radius),
        )

        if any(
            _boxes_overlap(box, existing, STAR_PADDING)
            for existing in placed_boxes
        ):
            continue

        alpha = int(210 + 45 * rng.random())
        if rng.random() < BRIGHT_STAR_CHANCE:
            alpha = 255

        placed_boxes.append(box)
        stars.append((x, y, radius, alpha))
        created += 1

    return stars


def draw_stars(img, stars, panel_index):
    """Draw stars belonging to one panel, including boundary-crossing stars."""
    panel_x_start = panel_index * PAGE_WIDTH
    panel_x_end = panel_x_start + PAGE_WIDTH

    overlay = Image.new(
        "RGBA",
        (PAGE_WIDTH, PAGE_HEIGHT),
        (0, 0, 0, 0),
    )
    draw = ImageDraw.Draw(overlay, "RGBA")

    for global_x, y, radius, alpha in stars:
        if global_x + radius < panel_x_start:
            continue
        if global_x - radius >= panel_x_end:
            continue

        local_x = int(round(global_x - panel_x_start))
        py = int(round(y))
        r = int(round(radius))

        draw.rectangle(
            (local_x - r, py - r, local_x + r, py + r),
            fill=(255, 255, 255, alpha),
        )

    result = img.convert("RGBA")
    result.alpha_composite(overlay)
    return result.convert("RGB")


# ============================================================
# EXPORT
# ============================================================

def create_preview(panel_paths, output_path):
    preview_width = 480
    preview_height = round(PAGE_HEIGHT * preview_width / PAGE_WIDTH)
    preview = Image.new(
        "RGB",
        (preview_width * SLIDE_COUNT, preview_height),
        (0, 0, 0),
    )

    for index, panel_path in enumerate(panel_paths):
        with Image.open(panel_path) as panel:
            thumbnail = panel.convert("RGB").resize(
                (preview_width, preview_height),
                Image.Resampling.LANCZOS,
            )
            preview.paste(thumbnail, (index * preview_width, 0))

    preview.save(output_path, quality=92, optimize=True)


def export_slides():
    out = Path(OUTPUT_DIR)
    out.mkdir(parents=True, exist_ok=True)

    print("Generating continuous star map...")
    stars = generate_stars()
    print(f"Placed {len(stars)} stars across the panorama.")

    panel_paths = []

    for panel_index in range(SLIDE_COUNT):
        slide_number = panel_index + 1
        print(f"Rendering slide {slide_number}/{SLIDE_COUNT}...")

        img = render_gradient_and_nebula(panel_index)
        img = draw_stars(img, stars, panel_index)

        output_path = out / PANEL_FILENAME.format(slide_number)
        temporary_path = output_path.with_suffix(".tmp.png")
        img.save(temporary_path, dpi=(DPI, DPI), optimize=True)
        os.replace(temporary_path, output_path)
        panel_paths.append(output_path)

    preview_path = out / PREVIEW_FILENAME
    print("Creating continuous panorama preview...")
    create_preview(panel_paths, preview_path)

    print()
    print("Done.")
    print(f"Output folder: {out.resolve()}")
    print(f"Slides: {SLIDE_COUNT}")
    print(f"Each slide: {PAGE_WIDTH}x{PAGE_HEIGHT}px")
    print(f"Virtual panorama: {TOTAL_WIDTH}x{TOTAL_HEIGHT}px")
    print(f"Preview: {preview_path.resolve()}")


if __name__ == "__main__":
    export_slides()
