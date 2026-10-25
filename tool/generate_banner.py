"""Generates the Google Play feature graphic (store banner), 1024x500.

Run from the project root after the store screenshots exist:

    python3 tool/generate_banner.py

Draws at 2x and downsamples for smooth edges. Uses the app's Manrope font,
its icon and two real screenshots from docs/play-store/screenshots/.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from generate_icons import STORE, full_icon, rounded

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'assets/fonts')
SHOTS = os.path.join(ROOT, 'docs/play-store/screenshots')

W, H = 2048, 1000  # 2x of 1024x500


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f'Manrope-{weight}.ttf'), size)


def backdrop():
    """Midnight base with vivid blurred colour fields, like the app."""
    img = Image.new('RGBA', (W, H))
    px = ImageDraw.Draw(img)
    top, bottom = (10, 12, 34), (24, 14, 58)
    for y in range(H):
        t = y / H
        px.line([(0, y), (W, y)], fill=tuple(
            int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    fields = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(fields)
    for box, color in [
        ((-300, -420, 760, 520), (124, 58, 237, 200)),   # violet
        ((1180, -360, 2300, 560), (37, 99, 235, 190)),    # blue
        ((1500, 420, 2400, 1300), (6, 182, 212, 150)),    # cyan
        ((560, 560, 1500, 1400), (219, 39, 119, 150)),    # pink
        ((-200, 640, 520, 1260), (245, 158, 11, 110)),    # amber
    ]:
        d.ellipse(box, fill=color)
    fields = fields.filter(ImageFilter.GaussianBlur(170))
    img = Image.alpha_composite(img, fields)
    # Faint grain-free sheen across the top.
    sheen = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    for y in range(H // 2):
        sd.line([(0, y), (W, y)], fill=(255, 255, 255, int(18 * (1 - y / (H / 2)))))
    return Image.alpha_composite(img, sheen)


def shadow(size, radius, blur, alpha):
    w, h = size
    pad = blur * 3
    s = Image.new('RGBA', (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(s).rounded_rectangle(
        [pad, pad, pad + w, pad + h], radius=radius, fill=(0, 0, 0, alpha))
    return s.filter(ImageFilter.GaussianBlur(blur)), pad


def phone(screenshot, height):
    """A slim phone frame around [screenshot]."""
    shot = Image.open(screenshot).convert('RGBA')
    bezel = int(height * 0.022)
    screen_h = height - bezel * 2
    screen_w = int(screen_h * shot.width / shot.height)
    w = screen_w + bezel * 2
    radius = int(w * 0.13)
    frame = Image.new('RGBA', (w, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, w - 1, height - 1], radius=radius,
                        fill=(14, 15, 28, 255))
    d.rounded_rectangle([1, 1, w - 2, height - 2], radius=radius,
                        outline=(255, 255, 255, 70), width=3)
    screen = shot.resize((screen_w, screen_h), Image.LANCZOS)
    mask = Image.new('L', screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, screen_w - 1, screen_h - 1], radius=radius - bezel, fill=255)
    frame.paste(screen, (bezel, bezel), mask)
    # Camera dot.
    cx, cy, r = w // 2, bezel + int(height * 0.018), int(height * 0.008)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(14, 15, 28, 255))
    return frame


def place(canvas, layer, center, angle, shadow_alpha=150):
    """Rotates [layer] and drops it on [canvas] with a soft shadow."""
    sh, pad = shadow(layer.size, int(layer.size[0] * 0.13), 40, shadow_alpha)
    sh = sh.rotate(angle, resample=Image.BICUBIC, expand=True)
    rot = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    cx, cy = center
    canvas.alpha_composite(sh, (int(cx - sh.width / 2 + 18),
                                int(cy - sh.height / 2 + 36)))
    canvas.alpha_composite(rot, (int(cx - rot.width / 2),
                                 int(cy - rot.height / 2)))


def glass_chip(canvas, xy, text, dot, size=34, dark=False):
    """Frosted pill: blurred backdrop, tint, bright rim, coloured dot.

    [dark] uses a deep tint so white text stays legible over bright screens.
    """
    f = font('Bold', size)
    d = ImageDraw.Draw(canvas)
    tb = d.textbbox((0, 0), text, font=f)
    pad_x, pad_y = int(size * 0.8), int(size * 0.55)
    dot_r = int(size * 0.28)
    w = pad_x * 2 + dot_r * 2 + int(size * 0.5) + (tb[2] - tb[0])
    h = pad_y * 2 + (tb[3] - tb[1])
    x, y = xy
    box = (x, y, x + w, y + h)
    region = canvas.crop(box).filter(ImageFilter.GaussianBlur(24))
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 2,
                                           fill=255)
    sh, spad = shadow((w, h), h // 2, 18, 110)
    canvas.alpha_composite(sh, (x - spad, y - spad + 10))
    canvas.paste(region, box[:2], mask)
    tint = Image.new('RGBA', (w, h),
                     (22, 18, 52, 190) if dark else (255, 255, 255, 46))
    canvas.paste(Image.alpha_composite(canvas.crop(box), tint), box[:2], mask)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(box, radius=h // 2, outline=(255, 255, 255, 120),
                        width=2)
    cy = y + h // 2
    d.ellipse([x + pad_x, cy - dot_r, x + pad_x + dot_r * 2, cy + dot_r],
              fill=dot)
    d.text((x + pad_x + dot_r * 2 + int(size * 0.5) - tb[0],
            y + pad_y - tb[1]), text, font=f, fill=(255, 255, 255, 255))
    return w, h


def main():
    canvas = backdrop()
    d = ImageDraw.Draw(canvas)

    # Brand block.
    icon = rounded(full_icon(150).convert('RGBA'), 0.24)
    sh, pad = shadow(icon.size, 36, 20, 140)
    canvas.alpha_composite(sh, (110 - pad, 150 - pad + 12))
    canvas.alpha_composite(icon, (110, 150))
    d.text((290, 150), 'FinFlow', font=font('Bold', 132),
           fill=(255, 255, 255, 255))
    d.text((114, 350), 'Spend smart. Split fair.', font=font('SemiBold', 64),
           fill=(255, 255, 255, 255))
    d.text((114, 432), 'Never miss a card bill.', font=font('SemiBold', 64),
           fill=(196, 188, 255, 255))

    # Feature pills.
    y = 580
    for text, dot in [
        ('Expenses & insights', (52, 211, 153, 255)),
        ('Split with roommates', (139, 124, 255, 255)),
        ('Card bills & EMIs', (251, 191, 36, 255)),
    ]:
        _, h = glass_chip(canvas, (110, y), text, dot)
        y += h + 22
    d = ImageDraw.Draw(canvas)
    d.text((114, y + 14), 'Private  ·  On-device  ·  No bank login',
           font=font('Medium', 32), fill=(169, 174, 207, 255))

    # Two phones with real screens, tilted and overlapping.
    back = phone(os.path.join(SHOTS, '02-split-group.png'), 860)
    front = phone(os.path.join(SHOTS, '01-home.png'), 940)
    place(canvas, back, (1380, 560), 9)
    place(canvas, front, (1720, 600), -7, shadow_alpha=170)

    # Floating glass chips over the phones.
    glass_chip(canvas, (1000, 96), 'You get back ₹225', (52, 211, 153, 255),
               size=32, dark=True)
    glass_chip(canvas, (1450, 846), 'Bill due in 8 days', (251, 191, 36, 255),
               size=32, dark=True)

    out = canvas.convert('RGB').resize((1024, 500), Image.LANCZOS)
    path = os.path.join(STORE, 'feature-graphic-1024x500.png')
    out.save(path, optimize=True)
    print('wrote', path)


if __name__ == '__main__':
    main()
