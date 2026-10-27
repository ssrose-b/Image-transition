#!/usr/bin/env python3
"""Resize a photo and export matching normal / Floyd-Steinberg RGB222 images."""
import argparse
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]

def convert(source):
    with Image.open(source) as opened:
        photo = ImageOps.fit(ImageOps.exif_transpose(opened).convert('RGB'),
                             (320, 240), method=Image.Resampling.LANCZOS)
    original = list(photo.getdata())
    normal = [tuple(min(3, int(v / 85 + 0.5)) for v in pixel) for pixel in original]
    work = [list(map(float, p)) for p in original]
    dithered = []
    for y in range(240):
        for x in range(320):
            i = y * 320 + x
            quant = tuple(min(3, max(0, int(v / 85 + 0.5))) for v in work[i])
            dithered.append(quant)
            for c in range(3):
                error = work[i][c] - quant[c] * 85
                for dx, dy, weight in ((1, 0, 7/16), (-1, 1, 3/16),
                                       (0, 1, 5/16), (1, 1, 1/16)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 320 and ny < 240:
                        work[ny * 320 + nx][c] += error * weight
    (ROOT / 'data').mkdir(exist_ok=True)
    (ROOT / 'images').mkdir(exist_ok=True)
    previews = []
    for name, pixels in (('bg1', normal), ('bg1_dithering', dithered)):
        (ROOT / 'data' / (name + '.mem')).write_text(''.join(
            f'{(r << 4) | (g << 2) | b:02x}\n' for r, g, b in pixels))
        preview = Image.new('RGB', (320, 240))
        preview.putdata([tuple(v * 85 for v in p) for p in pixels])
        preview.save(ROOT / 'images' / (name + '.png'))
        previews.append(preview)
    comparison = previews[0].copy()
    comparison.paste(previews[1].crop((0, 0, 160, 240)), (0, 0))
    for y in range(240):
        comparison.putpixel((159, y), (255, 255, 255))
        comparison.putpixel((160, y), (255, 255, 255))
    comparison.resize((640, 480), Image.Resampling.NEAREST).save(ROOT / 'images' / 'divider-preview.png')
    print('Generated two 76,800-pixel RGB222 memory files and previews.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=Path)
    convert(parser.parse_args().image)
