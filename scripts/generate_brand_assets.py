#!/usr/bin/env python3

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "mobile" / "befam"
BRANDING_ROOT = APP_ROOT / "assets" / "branding"
ANDROID_RES = APP_ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ASSETS = APP_ROOT / "ios" / "Runner" / "Assets.xcassets"
ARTIFACTS = ROOT / ".codex-artifacts"


@dataclass(frozen=True)
class Palette:
    midnight: str = "#30364F"
    midnight_light: str = "#46506F"
    cream: str = "#F0F0DB"
    sand: str = "#E1D9BC"
    mist: str = "#ACBAC4"
    outline: str = "#7E889B"
    white: str = "#FFFFFF"


PALETTE = Palette()


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    red, green, blue = ImageColor.getrgb(hex_color)
    return red, green, blue, alpha


def ensure_dirs() -> None:
    for path in [
        BRANDING_ROOT,
        BRANDING_ROOT / "logos",
        BRANDING_ROOT / "app-icon",
        BRANDING_ROOT / "splash",
        BRANDING_ROOT / "android",
        BRANDING_ROOT / "android" / "notification",
        BRANDING_ROOT / "android" / "adaptive",
        BRANDING_ROOT / "store",
        ARTIFACTS,
    ]:
        path.mkdir(parents=True, exist_ok=True)


def load_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    for candidate in candidates:
        font_path = Path(candidate)
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size=size)
    return ImageFont.load_default()


DISPLAY_FONT = [
    "/Library/Fonts/NewYork.ttf",
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf",
]
SERIF_FONT = [
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
    "/Library/Fonts/NewYork.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
]
SANS_FONT = [
    "/Library/Fonts/Avenir Next.ttc",
    "/System/Library/Fonts/Supplemental/Avenir.ttc",
    "/System/Library/Fonts/SFNS.ttf",
]


def lerp_channel(start: int, end: int, t: float) -> int:
    return round(start + (end - start) * t)


def lerp_color(start: str, end: str, t: float, alpha: int = 255) -> tuple[int, int, int, int]:
    sr, sg, sb = ImageColor.getrgb(start)
    er, eg, eb = ImageColor.getrgb(end)
    return (
        lerp_channel(sr, er, t),
        lerp_channel(sg, eg, t),
        lerp_channel(sb, eb, t),
        alpha,
    )


def vertical_gradient(size: tuple[int, int], top: str, bottom: str) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(height - 1, 1)
        draw.line([(0, y), (width, y)], fill=lerp_color(top, bottom, t))
    return image


def diagonal_gradient(size: tuple[int, int], start: str, end: str) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    pixels = image.load()
    for x in range(width):
        for y in range(height):
            t = (x + y) / max(width + height - 2, 1)
            pixels[x, y] = lerp_color(start, end, t)
    return image


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def regular_polygon_points(
    center: tuple[float, float],
    radius: float,
    sides: int,
    rotation_degrees: float = -90,
) -> list[tuple[float, float]]:
    return [
        (
            center[0] + math.cos(math.radians(rotation_degrees + (360 / sides) * index)) * radius,
            center[1] + math.sin(math.radians(rotation_degrees + (360 / sides) * index)) * radius,
        )
        for index in range(sides)
    ]


def alpha_composite_layers(base: Image.Image, layers: list[Image.Image]) -> Image.Image:
    output = base.copy()
    for layer in layers:
        output.alpha_composite(layer)
    return output


def draw_mark(
    size: int,
    orbit_colors: list[str],
    center_color: str,
    stroke_scale: float = 0.06,
    mono: bool = False,
) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    stroke = max(4, round(size * stroke_scale))
    orbit_box = (
        round(size * 0.2),
        round(size * 0.39),
        round(size * 0.8),
        round(size * 0.61),
    )
    angles = [14, 62, 118, 166]
    layers: list[Image.Image] = []
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(orbit_box, outline=(0, 0, 0, 80), width=max(2, stroke // 2))
    for angle in angles:
        rotated_shadow = shadow.rotate(angle, resample=Image.Resampling.BICUBIC)
        layers.append(rotated_shadow.filter(ImageFilter.GaussianBlur(max(1, stroke // 3))))

    orbit_fill = orbit_colors if not mono else [center_color] * len(angles)
    for angle, orbit_color in zip(angles, orbit_fill):
        orbit = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        orbit_draw = ImageDraw.Draw(orbit)
        orbit_draw.ellipse(orbit_box, outline=rgba(orbit_color), width=stroke)
        layers.append(orbit.rotate(angle, resample=Image.Resampling.BICUBIC))

    output = alpha_composite_layers(image, layers)
    draw = ImageDraw.Draw(output)

    inner_glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(inner_glow)
    glow_radius = size * 0.16
    glow_draw.ellipse(
        (
            size / 2 - glow_radius,
            size / 2 - glow_radius,
            size / 2 + glow_radius,
            size / 2 + glow_radius,
        ),
        fill=rgba(center_color, 62 if mono else 48),
    )
    output.alpha_composite(inner_glow.filter(ImageFilter.GaussianBlur(max(4, stroke))))

    core_points = regular_polygon_points((size / 2, size / 2), size * 0.062, 6)
    draw.polygon(core_points, fill=rgba(center_color))

    if not mono:
        halo_points = regular_polygon_points((size / 2, size / 2), size * 0.092, 6)
        draw.line(halo_points + [halo_points[0]], fill=rgba(PALETTE.outline, 96), width=max(2, stroke // 8))

    return output


def draw_simple_mark(size: int, color: str, stroke_scale: float = 0.09) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke = max(4, round(size * stroke_scale))
    orbit_box = (
        round(size * 0.22),
        round(size * 0.39),
        round(size * 0.78),
        round(size * 0.61),
    )

    for angle in (28, 152):
        orbit = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        orbit_draw = ImageDraw.Draw(orbit)
        orbit_draw.ellipse(orbit_box, outline=rgba(color), width=stroke)
        image.alpha_composite(orbit.rotate(angle, resample=Image.Resampling.BICUBIC))

    center_points = regular_polygon_points((size / 2, size / 2), size * 0.11, 6)
    draw.polygon(center_points, fill=rgba(color))
    return image


def draw_notification_mark(size: int, color: str) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke = max(3, round(size * 0.12))

    orbit = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    orbit_draw = ImageDraw.Draw(orbit)
    orbit_draw.ellipse(
        (
            round(size * 0.2),
            round(size * 0.38),
            round(size * 0.8),
            round(size * 0.62),
        ),
        outline=rgba(color),
        width=stroke,
    )
    image.alpha_composite(orbit.rotate(18, resample=Image.Resampling.BICUBIC))

    outer_points = regular_polygon_points((size / 2, size / 2), size * 0.17, 6)
    inner_points = regular_polygon_points((size / 2, size / 2), size * 0.1, 6)
    draw.line(outer_points + [outer_points[0]], fill=rgba(color), width=max(2, stroke // 2))
    draw.polygon(inner_points, fill=rgba(color))
    return image


def draw_wordmark(
    text_primary: str,
    text_secondary: str,
    size: tuple[int, int],
    primary_color: str,
    secondary_color: str,
    subtitle: str | None = None,
    subtitle_color: str | None = None,
) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    primary_font = load_font(SERIF_FONT, size=round(size[1] * 0.36))
    secondary_font = load_font(DISPLAY_FONT, size=round(size[1] * 0.42))
    subtitle_font = load_font(SANS_FONT, size=round(size[1] * 0.11))

    primary_box = draw.textbbox((0, 0), text_primary, font=primary_font)
    secondary_box = draw.textbbox((0, 0), text_secondary, font=secondary_font)
    primary_width = primary_box[2] - primary_box[0]
    secondary_width = secondary_box[2] - secondary_box[0]
    gap = round(size[0] * 0.012)
    total_width = primary_width + gap + secondary_width
    start_x = round((size[0] - total_width) / 2)
    baseline_y = round(size[1] * 0.16)

    draw.text((start_x, baseline_y + round(size[1] * 0.032)), text_primary, font=primary_font, fill=rgba(secondary_color))
    draw.text((start_x + primary_width + gap, baseline_y), text_secondary, font=secondary_font, fill=rgba(primary_color))

    if subtitle:
        subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
        subtitle_width = subtitle_box[2] - subtitle_box[0]
        subtitle_x = round((size[0] - subtitle_width) / 2)
        subtitle_y = round(size[1] * 0.72)
        draw.text(
            (subtitle_x, subtitle_y),
            subtitle,
            font=subtitle_font,
            fill=rgba(subtitle_color or primary_color, 210),
            spacing=6,
        )

    return image


def draw_stacked_logo(
    canvas_size: tuple[int, int],
    mark_colors: list[str],
    wordmark_primary: str,
    wordmark_secondary: str,
    subtitle_color: str,
    background: str | None = None,
) -> Image.Image:
    if background:
        image = vertical_gradient(canvas_size, background, background)
    else:
        image = Image.new("RGBA", canvas_size, (0, 0, 0, 0))

    mark = draw_mark(
        size=round(canvas_size[1] * 0.48),
        orbit_colors=mark_colors,
        center_color=wordmark_primary,
        stroke_scale=0.052,
    )
    wordmark = draw_wordmark(
        "Be",
        "Fam",
        (round(canvas_size[0] * 0.72), round(canvas_size[1] * 0.25)),
        primary_color=wordmark_primary,
        secondary_color=wordmark_secondary,
        subtitle="Family roots, beautifully connected.",
        subtitle_color=subtitle_color,
    )

    mark_x = round((canvas_size[0] - mark.width) / 2)
    mark_y = round(canvas_size[1] * 0.1)
    wordmark_x = round((canvas_size[0] - wordmark.width) / 2)
    wordmark_y = round(canvas_size[1] * 0.54)
    image.alpha_composite(mark, (mark_x, mark_y))
    image.alpha_composite(wordmark, (wordmark_x, wordmark_y))
    return image


def draw_app_icon(size: int = 1024) -> Image.Image:
    background = diagonal_gradient((size, size), PALETTE.midnight, PALETTE.midnight_light)
    soft_light = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    light_draw = ImageDraw.Draw(soft_light)
    light_draw.ellipse(
        (round(size * 0.14), round(size * 0.1), round(size * 0.86), round(size * 0.82)),
        fill=rgba(PALETTE.cream, 28),
    )
    background.alpha_composite(soft_light.filter(ImageFilter.GaussianBlur(round(size * 0.08))))

    mark = draw_mark(
        size=round(size * 0.6),
        orbit_colors=[PALETTE.cream, PALETTE.sand, PALETTE.mist, PALETTE.cream],
        center_color=PALETTE.cream,
        stroke_scale=0.06,
    )
    x = round((size - mark.width) / 2)
    y = round((size - mark.height) / 2)
    background.alpha_composite(mark, (x, y))

    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (round(size * 0.03), round(size * 0.03), round(size * 0.97), round(size * 0.97)),
        radius=round(size * 0.22),
        outline=rgba(PALETTE.cream, 96),
        width=round(size * 0.01),
    )
    background.alpha_composite(border)

    mask = rounded_mask((size, size), round(size * 0.22))
    rounded = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rounded.paste(background, (0, 0), mask)
    return rounded


def draw_splash_logo(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    mark = draw_mark(
        size=round(size[1] * 0.48),
        orbit_colors=[PALETTE.midnight, PALETTE.mist, PALETTE.sand, PALETTE.midnight],
        center_color=PALETTE.midnight,
        stroke_scale=0.055,
    )
    wordmark = draw_wordmark(
        "Be",
        "Fam",
        (round(size[0] * 0.84), round(size[1] * 0.28)),
        primary_color=PALETTE.midnight,
        secondary_color=PALETTE.mist,
    )
    mark_x = round((size[0] - mark.width) / 2)
    mark_y = round(size[1] * 0.05)
    wordmark_x = round((size[0] - wordmark.width) / 2)
    wordmark_y = round(size[1] * 0.62)
    image.alpha_composite(mark, (mark_x, mark_y))
    image.alpha_composite(wordmark, (wordmark_x, wordmark_y))
    return image


def draw_feature_graphic(size: tuple[int, int]) -> Image.Image:
    image = diagonal_gradient(size, PALETTE.midnight, PALETTE.midnight_light)
    soft_orbit = draw_mark(
        size=round(size[1] * 1.25),
        orbit_colors=[PALETTE.outline, PALETTE.mist, PALETTE.sand, PALETTE.outline],
        center_color=PALETTE.cream,
        stroke_scale=0.045,
    ).filter(ImageFilter.GaussianBlur(2))
    image.alpha_composite(soft_orbit, (round(size[0] * 0.54), round(size[1] * -0.32)))

    icon = draw_app_icon(264)
    image.alpha_composite(icon, (84, 118))

    wordmark = draw_wordmark(
        "Be",
        "Fam",
        (540, 160),
        primary_color=PALETTE.cream,
        secondary_color=PALETTE.sand,
        subtitle="Family roots, beautifully connected.",
        subtitle_color=PALETTE.cream,
    )
    image.alpha_composite(wordmark, (392, 122))

    accent = Image.new("RGBA", size, (0, 0, 0, 0))
    accent_draw = ImageDraw.Draw(accent)
    accent_draw.rounded_rectangle(
        (392, 332, 902, 396),
        radius=24,
        fill=rgba(PALETTE.cream, 24),
        outline=rgba(PALETTE.cream, 42),
        width=2,
    )
    image.alpha_composite(accent)
    headline_font = load_font(SANS_FONT, 34)
    text_draw = ImageDraw.Draw(image)
    text_draw.text((424, 347), "A trusted home for every family story.", font=headline_font, fill=rgba(PALETTE.cream))
    return image


def svg_header(size: tuple[int, int]) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size[0]}" height="{size[1]}" viewBox="0 0 {size[0]} {size[1]}">'


def orbit_svg(cx: int, cy: int, rx: int, ry: int, angle: int, color: str, width: int) -> str:
    return (
        f'<g transform="rotate({angle} {cx} {cy})">'
        f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="{color}" stroke-width="{width}" />'
        "</g>"
    )


def write_svg_logo(path: Path, background: str | None, dark: bool = False) -> None:
    width, height = 1600, 900
    bg_fill = f'<rect width="{width}" height="{height}" rx="44" fill="{background}" />' if background else ""
    primary = PALETTE.cream if dark else PALETTE.midnight
    secondary = PALETTE.sand if dark else PALETTE.mist
    subtitle = PALETTE.cream if dark else PALETTE.outline
    orbit_colors = [PALETTE.cream, PALETTE.sand, PALETTE.mist, PALETTE.cream] if dark else [PALETTE.midnight, PALETTE.mist, PALETTE.sand, PALETTE.midnight]
    svg = [
        svg_header((width, height)),
        bg_fill,
        orbit_svg(800, 235, 158, 58, 14, orbit_colors[0], 24),
        orbit_svg(800, 235, 158, 58, 62, orbit_colors[1], 24),
        orbit_svg(800, 235, 158, 58, 118, orbit_colors[2], 24),
        orbit_svg(800, 235, 158, 58, 166, orbit_colors[3], 24),
        f'<polygon points="800,196 835,216 835,256 800,276 765,256 765,216" fill="{primary}" />',
        f'<text x="682" y="550" font-family="New York, Georgia, serif" font-size="136" fill="{secondary}">Be</text>',
        f'<text x="846" y="540" font-family="New York, Georgia, serif" font-size="160" font-weight="700" fill="{primary}">Fam</text>',
        f'<text x="800" y="650" font-family="Avenir Next, Helvetica, sans-serif" font-size="34" fill="{subtitle}" text-anchor="middle" letter-spacing="0.08em">Family roots, beautifully connected.</text>',
        "</svg>",
    ]
    path.write_text("\n".join(svg), encoding="utf-8")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG")


def save_resized(image: Image.Image, path: Path, size: tuple[int, int]) -> None:
    resized = image.resize(size, Image.Resampling.LANCZOS)
    save_png(resized, path)


def generate_shared_assets() -> dict[str, Image.Image]:
    primary_logo = draw_stacked_logo(
        (1600, 900),
        [PALETTE.midnight, PALETTE.mist, PALETTE.sand, PALETTE.midnight],
        wordmark_primary=PALETTE.midnight,
        wordmark_secondary=PALETTE.mist,
        subtitle_color=PALETTE.outline,
    )
    light_logo = draw_stacked_logo(
        (1600, 900),
        [PALETTE.midnight, PALETTE.mist, PALETTE.sand, PALETTE.midnight],
        wordmark_primary=PALETTE.midnight,
        wordmark_secondary=PALETTE.mist,
        subtitle_color=PALETTE.outline,
        background=PALETTE.cream,
    )
    dark_logo = draw_stacked_logo(
        (1600, 900),
        [PALETTE.cream, PALETTE.sand, PALETTE.mist, PALETTE.cream],
        wordmark_primary=PALETTE.cream,
        wordmark_secondary=PALETTE.sand,
        subtitle_color=PALETTE.cream,
        background=PALETTE.midnight,
    )
    app_icon = draw_app_icon(1024)
    splash_logo = draw_splash_logo((1200, 1200))
    feature_graphic = draw_feature_graphic((1024, 500))

    save_png(primary_logo, BRANDING_ROOT / "logos" / "logo-primary.png")
    save_png(light_logo, BRANDING_ROOT / "logos" / "logo-light.png")
    save_png(dark_logo, BRANDING_ROOT / "logos" / "logo-dark.png")
    save_png(app_icon, BRANDING_ROOT / "app-icon" / "app-icon-1024.png")
    save_png(splash_logo, BRANDING_ROOT / "splash" / "splash-logo.png")
    save_png(feature_graphic, BRANDING_ROOT / "store" / "google-play-feature-graphic.png")

    write_svg_logo(BRANDING_ROOT / "logos" / "logo-primary.svg", background=None)
    write_svg_logo(BRANDING_ROOT / "logos" / "logo-light.svg", background=PALETTE.cream)
    write_svg_logo(BRANDING_ROOT / "logos" / "logo-dark.svg", background=PALETTE.midnight, dark=True)

    return {
        "primary_logo": primary_logo,
        "light_logo": light_logo,
        "dark_logo": dark_logo,
        "app_icon": app_icon,
        "splash_logo": splash_logo,
        "feature_graphic": feature_graphic,
    }


def generate_android_assets(app_icon: Image.Image, splash_logo: Image.Image) -> None:
    launcher_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
        "mipmap-mdpi/ic_launcher_round.png": 48,
        "mipmap-hdpi/ic_launcher_round.png": 72,
        "mipmap-xhdpi/ic_launcher_round.png": 96,
        "mipmap-xxhdpi/ic_launcher_round.png": 144,
        "mipmap-xxxhdpi/ic_launcher_round.png": 192,
    }
    for relative_path, icon_size in launcher_sizes.items():
        save_resized(app_icon, ANDROID_RES / relative_path, (icon_size, icon_size))

    adaptive_foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    mark = draw_mark(
        size=250,
        orbit_colors=[PALETTE.cream, PALETTE.sand, PALETTE.mist, PALETTE.cream],
        center_color=PALETTE.cream,
        stroke_scale=0.064,
    )
    adaptive_foreground.alpha_composite(mark, ((432 - mark.width) // 2, (432 - mark.height) // 2))
    save_png(adaptive_foreground, ANDROID_RES / "drawable" / "ic_launcher_foreground.png")

    monochrome = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    mono_mark = draw_simple_mark(size=240, color=PALETTE.white, stroke_scale=0.08)
    monochrome.alpha_composite(mono_mark, ((432 - mono_mark.width) // 2, (432 - mono_mark.height) // 2))
    save_png(monochrome, ANDROID_RES / "drawable" / "ic_launcher_monochrome.png")

    notification_sizes = {
        "drawable-mdpi/ic_notification_befam.png": 24,
        "drawable-hdpi/ic_notification_befam.png": 36,
        "drawable-xhdpi/ic_notification_befam.png": 48,
        "drawable-xxhdpi/ic_notification_befam.png": 72,
        "drawable-xxxhdpi/ic_notification_befam.png": 96,
    }
    notification_base = draw_notification_mark(size=96, color=PALETTE.white)
    alpha = notification_base.getchannel("A")
    padded = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    padded.paste(notification_base, (0, 0), alpha)
    for relative_path, edge in notification_sizes.items():
        save_resized(padded, ANDROID_RES / relative_path, (edge, edge))

    save_png(splash_logo.resize((720, 720), Image.Resampling.LANCZOS), ANDROID_RES / "drawable-nodpi" / "launch_logo.png")

    save_png(app_icon, BRANDING_ROOT / "android" / "legacy-launcher-1024.png")
    save_png(adaptive_foreground, BRANDING_ROOT / "android" / "adaptive" / "adaptive-foreground-432.png")
    save_png(monochrome, BRANDING_ROOT / "android" / "adaptive" / "adaptive-monochrome-432.png")
    save_png(notification_base, BRANDING_ROOT / "android" / "notification" / "notification-icon-96.png")


def generate_ios_assets(app_icon: Image.Image, splash_logo: Image.Image) -> None:
    icon_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, edge in icon_sizes.items():
        save_resized(app_icon, IOS_ASSETS / "AppIcon.appiconset" / filename, (edge, edge))

    launch_sizes = {
        "LaunchImage.png": (168, 185),
        "LaunchImage@2x.png": (336, 370),
        "LaunchImage@3x.png": (504, 555),
    }
    for filename, size in launch_sizes.items():
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        splash_copy = splash_logo.resize((round(size[0] * 0.86), round(size[1] * 0.86)), Image.Resampling.LANCZOS)
        x = (size[0] - splash_copy.width) // 2
        y = (size[1] - splash_copy.height) // 2
        canvas.alpha_composite(splash_copy, (x, y))
        save_png(canvas, IOS_ASSETS / "LaunchImage.imageset" / filename)


def create_preview(primary_logo: Image.Image, app_icon: Image.Image, dark_logo: Image.Image, feature_graphic: Image.Image) -> None:
    preview = Image.new("RGBA", (1800, 1320), rgba(PALETTE.cream))
    draw = ImageDraw.Draw(preview)
    title_font = load_font(DISPLAY_FONT, 64)
    label_font = load_font(SANS_FONT, 28)
    draw.text((72, 58), "BeFam production brand pack", font=title_font, fill=rgba(PALETTE.midnight))

    preview.alpha_composite(app_icon.resize((280, 280), Image.Resampling.LANCZOS), (94, 176))
    draw.text((122, 478), "App icon", font=label_font, fill=rgba(PALETTE.midnight))

    preview.alpha_composite(primary_logo.resize((880, 495), Image.Resampling.LANCZOS), (448, 124))
    draw.text((448, 642), "Primary logo", font=label_font, fill=rgba(PALETTE.midnight))

    preview.alpha_composite(dark_logo.resize((880, 495), Image.Resampling.LANCZOS), (448, 732))
    draw.text((448, 1250), "Dark logo", font=label_font, fill=rgba(PALETTE.midnight))

    preview.alpha_composite(feature_graphic.resize((560, 274), Image.Resampling.LANCZOS), (94, 720))
    draw.text((94, 1018), "Store feature graphic", font=label_font, fill=rgba(PALETTE.midnight))

    save_png(preview, ARTIFACTS / "befam-brand-preview.png")


def main() -> None:
    ensure_dirs()
    shared = generate_shared_assets()
    generate_android_assets(shared["app_icon"], shared["splash_logo"])
    generate_ios_assets(shared["app_icon"], shared["splash_logo"])
    create_preview(shared["primary_logo"], shared["app_icon"], shared["dark_logo"], shared["feature_graphic"])
    print(f"Generated BeFam brand assets in {BRANDING_ROOT}")


if __name__ == "__main__":
    main()
