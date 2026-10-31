#!/usr/bin/env python3
"""Generate GADESK bitmap assets from brand-mark.svg; requires Pillow."""
import argparse
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont


def render_svg(path, width, height):
    # The master uses only stroked M/L/H/V/C paths and circles.
    root = ET.parse(path).getroot()
    image = Image.new('RGBA', (width * 4, height * 4))
    draw = ImageDraw.Draw(image)
    box = list(map(float, root.attrib['viewBox'].split()))
    sx, sy = image.width / box[2], image.height / box[3]

    def render(element, inherited):
        attributes = inherited.copy()
        attributes.update(element.attrib)
        stroke = attributes.get('stroke')
        stroke_width = max(1, round(float(attributes.get('stroke-width', 1)) * sx))

        if element.tag.endswith('path'):
            tokens = re.findall(r'[A-Za-z]|-?\d+(?:\.\d+)?', attributes['d'])
            index, command, point, points = 0, None, (0, 0), []

            def flush():
                if len(points) < 2:
                    return
                scaled = [(round(x * sx), round(y * sy)) for x, y in points]
                draw.line(scaled, fill=stroke, width=stroke_width, joint='curve')
                if attributes.get('stroke-linecap') == 'round':
                    radius = stroke_width / 2
                    for x, y in (scaled[0], scaled[-1]):
                        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=stroke)

            while index < len(tokens):
                if tokens[index].isalpha():
                    command = tokens[index]
                    index += 1
                counts = {'M': 2, 'L': 2, 'C': 6, 'V': 1, 'H': 1}
                if command not in counts:
                    raise ValueError(f'Unsupported SVG command: {command}')
                count = counts[command]
                values = list(map(float, tokens[index:index+count]))
                index += count
                if command == 'M':
                    flush()
                    point, points, command = tuple(values), [tuple(values)], 'L'
                elif command == 'L':
                    point = tuple(values)
                    points.append(point)
                elif command == 'V':
                    point = (point[0], values[0])
                    points.append(point)
                elif command == 'H':
                    point = (values[0], point[1])
                    points.append(point)
                elif command == 'C':
                    p0, p1, p2, p3 = point, values[:2], values[2:4], values[4:]
                    for step in range(1, 49):
                        t = step / 48
                        u = 1 - t
                        points.append(tuple(
                            u**3*p0[k] + 3*u*u*t*p1[k] + 3*u*t*t*p2[k] + t**3*p3[k]
                            for k in range(2)))
                    point = tuple(p3)
            flush()
        elif element.tag.endswith('circle'):
            x = float(attributes['cx']) * sx
            y = float(attributes['cy']) * sy
            radius = float(attributes['r']) * sx + stroke_width / 2
            draw.ellipse((x-radius, y-radius, x+radius, y+radius),
                         outline=stroke, width=stroke_width)
        for child in element:
            render(child, attributes)

    render(root, {})
    return image.resize((width, height), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', default='/System/Library/Fonts/Supplemental/Arial.ttf')
    parser.add_argument('--bold-font', default='/System/Library/Fonts/Supplemental/Arial Bold.ttf')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    master = root / 'res/gadesk/brand-mark.svg'
    mark = render_svg(master, 810, 1150)
    mark = mark.crop(mark.getbbox())

    def icon(size=1024, background=None, fraction=0.84, inset=0):
        image = Image.new('RGBA', (1024, 1024))
        if background:
            ImageDraw.Draw(image).rounded_rectangle(
                (inset, inset, 1023-inset, 1023-inset),
                radius=(1024-2*inset)*0.22, fill=background)
        height = round(1024*fraction)
        artwork = mark.resize((round(mark.width*height/mark.height), height), Image.Resampling.LANCZOS)
        image.alpha_composite(artwork, ((1024-artwork.width)//2, (1024-height)//2))
        return image.resize((size, size), Image.Resampling.LANCZOS)

    def silhouette(image, color):
        result = Image.new('RGBA', image.size, color)
        result.putalpha(image.getchannel('A'))
        return result

    app = icon(background='white')
    app.save(root/'res/icon.png')
    mac = icon(background='white', fraction=0.67, inset=96)
    mac.save(root/'res/mac-icon.png')
    mac.save(root/'flutter/macos/Runner/AppIcon.icns', format='ICNS')
    icon().save(root/'flutter/assets/icon.png')
    for path in ['flutter/assets/icon.svg', 'deploy/gadesk/downloads/icon.svg']:
        shutil.copyfile(master, root/path)
    for path in ['res/icon.ico', 'flutter/windows/runner/resources/app_icon.ico']:
        app.save(root/path, sizes=[(n,n) for n in [16,24,32,48,64,128,256]])
    icon().save(root/'res/tray-icon.ico', sizes=[(n,n) for n in [16,24,32,48]])
    for name, size, color in [('dark',60,'black'),('light',48,'white')]:
        silhouette(icon(size, fraction=0.92),color).save(root/f'res/mac-tray-{name}-x2.png')
    for density, launcher, foreground, notification in [
            ('mdpi',48,108,24), ('hdpi',72,162,36), ('xhdpi',96,216,48),
            ('xxhdpi',144,324,72), ('xxxhdpi',192,432,96)]:
        out = root/'flutter/android/app/src/main/res'/('mipmap-'+density)
        icon(launcher, background='white').save(out/'ic_launcher.png')
        icon(launcher, background='white').save(out/'ic_launcher_round.png')
        icon(foreground, fraction=0.60).save(out/'ic_launcher_foreground.png')
        silhouette(icon(notification, fraction=0.92),'white').save(out/'ic_stat_logo.png')
    colors = root/'flutter/android/app/src/main/res/values/ic_launcher_background.xml'
    text = colors.read_text()
    text = re.sub(r'(<color name="ic_launcher_background">)#[0-9a-fA-F]{6}',r'\1#ffffff',text)
    colors.write_text(text)
    font = ImageFont.truetype(args.bold_font, 102)
    small = ImageFont.truetype(args.font, 32)
    for name, color in [('logo.png','#213347'),('logo_light.png','#213347'),('logo_dark.png','white')]:
        logo = Image.new('RGBA',(720,240))
        logo.alpha_composite(icon(210, fraction=0.94),(0,15))
        draw = ImageDraw.Draw(logo)
        draw.text((230,27),'GADESK',font=font,fill=color)
        draw.text((235,151),'GRUPO AMAYO',font=small,fill=color)
        logo.save(root/'flutter/assets'/name)
    output = root/'target/gadesk-branding'
    output.mkdir(parents=True, exist_ok=True)
    mark.save(output/'brand-mark-preview.png')
    preview = Image.new('RGBA',(1100,520),'#edf2f7')
    preview.alpha_composite(app.resize((360,360)),(30,30))
    logo = Image.open(root/'flutter/assets/logo_light.png')
    logo.thumbnail((660,220)); preview.alpha_composite(logo,(420,70))
    for i, size in enumerate([16,24,32,48,64]):
        small_icon=icon(size,background='white');preview.alpha_composite(small_icon,(430+i*100,360))
    preview.convert('RGB').save(output/'assets-preview.png')
    print('Updated GADESK platform assets; preview:',output/'assets-preview.png')


if __name__ == '__main__':
    main()
