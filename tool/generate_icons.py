"""Generates FinFlow's launcher, store and notification icons.

Run from the project root:  python3 tool/generate_icons.py
Requires Pillow. Output paths are under android/ and docs/play-store/.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'assets/fonts/Manrope-Bold.ttf')
RES = os.path.join(ROOT, 'android/app/src/main/res')
STORE = os.path.join(ROOT, 'docs/play-store/graphics')

STOPS = [(0.0, (109, 40, 217)), (0.55, (192, 38, 211)), (1.0, (249, 115, 22))]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, stops=STOPS):
    """Diagonal (top-left to bottom-right) multi-stop gradient."""
    w, h = size
    img = Image.new('RGB', size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t0 <= t <= t1:
                    px[x, y] = lerp(c0, c1, (t - t0) / (t1 - t0))
                    break
    return img


def background(n):
    """Holographic gradient with soft light orbs and a glass highlight."""
    img = gradient((n, n)).convert('RGBA')
    glow = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse([n * 0.55, -n * 0.25, n * 1.35, n * 0.55], fill=(34, 211, 238, 120))
    d.ellipse([-n * 0.35, n * 0.6, n * 0.45, n * 1.4], fill=(251, 191, 36, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.12))
    img = Image.alpha_composite(img, glow)
    sheen = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    for y in range(n // 2):
        a = int(70 * (1 - y / (n / 2)))
        sd.line([(0, y), (n, y)], fill=(255, 255, 255, a))
    return Image.alpha_composite(img, sheen)


def mark(n, color=(255, 255, 255, 255), safe=0.62):
    """The FinFlow mark (coin ring, rupee sign, flow wave) on transparency.

    [safe] is the fraction of the canvas the mark may occupy (adaptive icons
    keep artwork inside the central 66%).
    """
    s = n * 4  # supersample for smooth edges
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = s * safe / 2
    c = s / 2
    ring = s * 0.045
    d.ellipse([c - r, c - r, c + r, c + r], outline=color, width=int(ring))
    font = ImageFont.truetype(FONT, int(r * 1.15))
    box = d.textbbox((0, 0), '₹', font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    d.text((c - tw / 2 - box[0], c - th / 2 - box[1] - r * 0.08), '₹',
           font=font, fill=color)
    # Flow wave under the symbol, inside the ring.
    # Drawn with a round brush: PIL's wide polylines leave notches.
    brush = ring * 0.4
    for i in range(401):
        t = i / 400
        x = c - r * 0.5 + t * r * 1.0
        y = c + r * 0.55 + math.sin(t * math.pi * 2) * r * 0.07
        d.ellipse([x - brush, y - brush, x + brush, y + brush], fill=color)
    return img.resize((n, n), Image.LANCZOS)


def rounded(img, radius_frac):
    n = img.size[0]
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, n - 1, n - 1],
                                        radius=int(n * radius_frac), fill=255)
    out = img.copy()
    out.putalpha(m)
    return out


def circle(img):
    n = img.size[0]
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).ellipse([0, 0, n - 1, n - 1], fill=255)
    out = img.copy()
    out.putalpha(m)
    return out


def full_icon(n):
    """Background + mark, square (used for legacy and store icons)."""
    bg = background(n)
    return Image.alpha_composite(bg, mark(n, safe=0.56))


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def main():
    densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    master = full_icon(1024)
    for name, k in densities.items():
        legacy = int(48 * k)
        save(rounded(master, 0.22).resize((legacy, legacy), Image.LANCZOS),
             f'{RES}/mipmap-{name}/ic_launcher.png')
        save(circle(master).resize((legacy, legacy), Image.LANCZOS),
             f'{RES}/mipmap-{name}/ic_launcher_round.png')
        layer = int(108 * k)
        save(mark(layer), f'{RES}/mipmap-{name}/ic_launcher_foreground.png')
        save(background(layer), f'{RES}/mipmap-{name}/ic_launcher_background.png')
        save(mark(layer), f'{RES}/mipmap-{name}/ic_launcher_monochrome.png')
        stat = int(24 * k)
        save(mark(stat, safe=0.9), f'{RES}/drawable-{name}/ic_stat_finflow.png')

    os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'''
    for name in ('ic_launcher', 'ic_launcher_round'):
        with open(f'{RES}/mipmap-anydpi-v26/{name}.xml', 'w') as f:
            f.write(adaptive)

    # Play Store: 512x512 icon (Play applies its own rounding).
    save(master.resize((512, 512), Image.LANCZOS).convert('RGB'),
         f'{STORE}/icon-512.png')
    # Feature graphic 1024x500.
    fg = gradient((1024, 500)).convert('RGBA')
    glow = Image.new('RGBA', (1024, 500), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([600, -250, 1200, 350], fill=(34, 211, 238, 110))
    gd.ellipse([-200, 250, 400, 850], fill=(251, 191, 36, 90))
    fg = Image.alpha_composite(fg, glow.filter(ImageFilter.GaussianBlur(80)))
    m = mark(300, safe=0.8)
    fg.alpha_composite(m, (90, 100))
    d = ImageDraw.Draw(fg)
    title = ImageFont.truetype(FONT, 104)
    sub = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/Manrope-Medium.ttf'), 40)
    d.text((440, 150), 'FinFlow', font=title, fill='white')
    d.text((446, 285), 'Money, beautifully clear', font=sub,
           fill=(255, 255, 255, 230))
    save(fg.convert('RGB'), f'{STORE}/feature-graphic-1024x500.png')
    save(rounded(master, 0.22).resize((256, 256), Image.LANCZOS),
         os.path.join(ROOT, 'docs/play-store/graphics/icon-preview.png'))
    print('icons written')


if __name__ == '__main__':
    main()
