#!/usr/bin/env python3
"""Generate the Frog Native asset kit with native macOS SVG rendering.

The Swift theme is the source of truth for colors; this file owns brand/glyph geometry.
No downloaded artwork, Apple symbol exports, or generative raster source is required.
"""
from pathlib import Path
import base64
import hashlib
import json
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets'
BRAND_RESOURCE = ROOT / 'Sources/frog-native/Resources/Brand'
INK_NAMES = ['ink', 'ink2', 'ink3', 'blue', 'good', 'bad', 'warn', 'cyan', 'violet']
SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256, 512, 1024]
ICONSET = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]


def palettes():
    source = (ROOT / 'Sources/frog-native/Models/FileManagerTheme.swift').read_text()
    result = {}
    for mode in ['dark', 'light']:
        block = source.split(f'static let {mode} = FileManagerPalette(')[1].split('\n    )')[0]
        colors = {name: '#' + value for name, value in re.findall(r'(\w+): Color\(solarized: 0x([0-9a-f]+)\)', block)}
        ink, raised = re.findall(r'(?:ink|raisedInk): ThemeInk\(([^)]+)\)', block)
        for name, value in zip(INK_NAMES, ink.split(','), strict=True):
            colors[name] = '#' + value.strip().removeprefix('0x')
        colors['raised'] = {name: '#' + value.strip().removeprefix('0x') for name, value in zip(INK_NAMES, raised.split(','), strict=True)}
        result[mode] = colors
    return result


def write(relative, content):
    path = OUT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return path


def svg(body, width=1024, height=1024):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n'


def mark(p, small=False, mono=None):
    green = mono or p['good']
    blue = mono or p['blue']
    cut = p['bg']
    # Frog eyes crown a folder silhouette. The lower fold evokes the two-pane browser.
    body = f'<path fill="{green}" d="M208 450 Q208 358 290 354 V326 A112 112 0 0 1 514 326 A112 112 0 0 1 738 326 V354 Q816 358 816 450 V658 Q816 744 730 744 H294 Q208 744 208 658Z"/>'
    if mono:
        # Even-odd holes preserve transparency for monochrome/tray uses.
        body = f'<path fill="{mono}" fill-rule="evenodd" d="M208 450 Q208 358 290 354 V326 A112 112 0 0 1 514 326 A112 112 0 0 1 738 326 V354 Q816 358 816 450 V658 Q816 744 730 744 H294 Q208 744 208 658Z M368 326 A34 34 0 1 0 436 326 A34 34 0 1 0 368 326Z M592 326 A34 34 0 1 0 660 326 A34 34 0 1 0 592 326Z M360 540 Q512 646 664 540 L664 588 Q512 694 360 588Z"/>'
        return body
    for cx in [402, 626]:
        body += f'<circle cx="{cx}" cy="326" r="{36 if small else 38}" fill="{cut}"/>'
    if not small:
        body += f'<path d="M366 518 Q512 608 658 518" fill="none" stroke="{cut}" stroke-width="32" stroke-linecap="round"/>'
    # Folder front with a stepped tab: readable at all sizes, no hairlines.
    body += f'<path fill="{blue}" d="M208 628 H414 L462 670 H816 V706 Q816 790 732 790 H292 Q208 790 208 706Z"/>'
    if not small:
        body += f'<path d="M512 694 V754" stroke="{cut}" stroke-width="20" stroke-linecap="round"/>'
    return body


def icon(p, small=False, square=False):
    x, side, radius = (0,1024,0) if square else (80,864,190)
    return svg(f'<rect x="{x}" y="{x}" width="{side}" height="{side}" rx="{radius}" fill="{p["bg"]}"/>' + mark(p,small))


# Original geometric UI glyphs on a 24-point grid. These are not SF Symbols exports.
GLYPHS = {
 'folder': ('blue','<path d="M3 7V5h6l2 2h10v13H3Z"/>'),
 'folder-open': ('blue','<path d="M3 10V5h6l2 2h9v3M3 10h19l-3 10H3Z"/>'),
 'file': ('ink2','<path d="M6 3h8l4 4v14H6ZM14 3v5h4"/>'),
 'text': ('ink2','<path d="M6 3h8l4 4v14H6ZM14 3v5h4M9 12h6M9 16h6"/>'),
 'code': ('ink2','<path d="m8 7-5 5 5 5m8-10 5 5-5 5m-3-13-2 16"/>'),
 'image': ('ink2','<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8" cy="8" r="1.5"/><path d="m3 18 6-6 4 4 3-3 5 5"/>'),
 'archive': ('violet','<path d="M5 3h14v18H5ZM12 3v9m-2 2h4v4h-4Z"/>'),
 'link': ('cyan','<path d="m10 8 3-3a4 4 0 0 1 6 6l-3 3m-2 2-3 3a4 4 0 0 1-6-6l3-3m0 6 8-8"/>'),
 'executable': ('good','<path d="m9 4 11 8-11 8ZM4 4v16"/>'),
 'drive': ('cyan','<path d="m5 4-3 12v4h20v-4L19 4ZM2 15h20M17 18h2"/>'),
 'cloud': ('cyan','<path d="M7 18H6a4 4 0 0 1-1-8 7 7 0 0 1 14-1 4.5 4.5 0 0 1 0 9h-2M12 20V10m-3 3 3-3 3 3"/>'),
 'tag': ('violet','<path d="M3 3h8l10 10-8 8L3 11Z"/><circle cx="7" cy="7" r="1"/>'),
 'search': ('ink2','<circle cx="10" cy="10" r="6"/><path d="m15 15 6 6"/>'),
 'settings': ('ink2','<path d="M4 6h16M4 12h16M4 18h16"/><path d="M8 3v6m8 0v6M10 15v6"/>'),
 'copy': ('ink2','<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 5V3H3v13h2"/>'),
 'move': ('ink2','<path d="M3 8h8v13H3ZM10 4h11m-4-3 4 3-4 3M15 12h6v9h-6"/>'),
 'trash': ('bad','<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7"/>'),
 'add': ('good','<path d="M12 4v16M4 12h16"/>'),
 'check': ('good','<path d="m4 12 5 5L20 6"/>'),
 'warning': ('warn','<path d="m12 3 10 18H2ZM12 9v5m0 3v1"/>'),
 'error': ('bad','<circle cx="12" cy="12" r="9"/><path d="m8 8 8 8M16 8l-8 8"/>'),
 'modified': ('warn','<path d="m5 15 11-11 4 4L9 19l-6 2ZM13 7l4 4"/>'),
 'untracked': ('ink3','<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 1 1 5 2c-2 1-2 2-2 3m0 3v1"/>'),
 'back': ('ink2','<path d="m14 4-8 8 8 8"/>'),
 'forward': ('ink2','<path d="m10 4 8 8-8 8"/>'),
 'up': ('ink2','<path d="m4 14 8-8 8 8"/>'),
 'refresh': ('ink2','<path d="M20 8A8 8 0 1 0 21 14M20 3v5h-5"/>'),
 'hidden': ('ink3','<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/><path d="m3 3 18 18"/>'),
 'split-pane': ('ink2','<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M12 3v18M6 7h3m6 0h3M6 11h3m6 0h3"/>'),
 'tree': ('ink2','<path d="M5 3v15h5M5 8h5M14 6h7v4h-7ZM14 16h7v4h-7Z"/>'),
}


def pack_ico(path, pngs):
    offset = 6 + 16 * len(pngs)
    entries, payload = [], []
    for size, data in pngs:
        entries.append(struct.pack('<BBBBHHII', size if size < 256 else 0, size if size < 256 else 0, 0, 0, 1, 32, len(data), offset))
        payload.append(data)
        offset += len(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack('<HHH', 0, 1, len(pngs)) + b''.join(entries + payload))


def main():
    colors = palettes()
    OUT.mkdir(exist_ok=True)
    BRAND_RESOURCE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='frog-assets-') as temp:
        renderer = Path(temp) / 'render-svg'
        subprocess.run(['swiftc', str(ROOT/'scripts/render-svg.swift'), '-o', str(renderer)], check=True)
        def render(source, dest, width):
            dest.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run([str(renderer), str(source), str(dest), str(width)], check=True)

        for mode, p in colors.items():
            normal = write(f'Source/app-icon-{mode}.svg', icon(p))
            small = write(f'Source/app-icon-{mode}-small.svg', icon(p, small=True))
            square = write(f'Source/app-icon-{mode}-square.svg', icon(p, square=True))
            brand = write(f'Brand/frog-mark-{mode}.svg', svg(mark(p)))
            mono = write(f'Brand/frog-mark-{mode}-mono.svg', svg(mark(p, mono=p['ink'])))
            render(brand, OUT/f'Brand/frog-mark-{mode}.png', 1024)
            render(mono, OUT/f'Brand/frog-mark-{mode}-mono.png', 1024)
            for size in SIZES:
                render(small if size <= 32 else normal, OUT/f'Icons/{mode}/app-{size}.png', size)
            for size in [192,512]:
                render(square, OUT/f'Web/{mode}/icon-{size}.png', size)
            render(square, OUT/f'Web/{mode}/apple-touch-icon.png',180)
            render(square, OUT/f'Web/{mode}/maskable-512.png',512)
            pack_ico(OUT/f'Windows/FrogNative-{mode}.ico', [(size,(OUT/f'Icons/{mode}/app-{size}.png').read_bytes()) for size in SIZES if size<=256])
            pack_ico(OUT/f'Web/{mode}/favicon.ico', [(size,(OUT/f'Icons/{mode}/app-{size}.png').read_bytes()) for size in [16,32,48]])
            write(f'Web/{mode}/favicon.svg', icon(p))
            write(f'Web/{mode}/site.webmanifest',json.dumps({'name':'Frog Native','short_name':'Frog','display':'standalone','background_color':p['bg'],'theme_color':p['bg2'],'icons':[{'src':f'icon-{size}.png','sizes':f'{size}x{size}','type':'image/png','purpose':'any'} for size in [192,512]]+[{'src':'maskable-512.png','sizes':'512x512','type':'image/png','purpose':'maskable'}]},indent=2)+'\n')
            lockup = svg(f'<g transform="translate(-50 -38) scale(.40)">{mark(p)}</g><text x="350" y="192" fill="{p["ink"]}" font-family="Helvetica Neue,Arial,sans-serif" font-size="100" font-weight="600" letter-spacing="-3">Frog Native</text>',1000,320)
            lockup_path=write(f'Brand/wordmark-{mode}.svg',lockup)
            render(lockup_path, OUT/f'Brand/wordmark-{mode}.png',2000)
            linux=OUT/f'Linux/{mode}/hicolor'
            for size in [16,24,32,48,64,128,256,512]:
                dest=linux/f'{size}x{size}/apps/frog-native.png';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(OUT/f'Icons/{mode}/app-{size}.png',dest)
            dest=linux/'scalable/apps/frog-native.svg';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(normal,dest)
            appset=OUT/f'macOS/{mode}/AppIcon.iconset';appset.mkdir(parents=True,exist_ok=True)
            catalog=OUT/f'macOS/{mode}/Assets.xcassets/AppIcon.appiconset';catalog.mkdir(parents=True,exist_ok=True)
            (catalog.parent/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
            images=[]
            for size,scale in ICONSET:
                filename=f'icon_{size}x{size}'+('@2x' if scale==2 else '')+'.png'
                for dest in [appset/filename,catalog/filename]:shutil.copyfile(OUT/f'Icons/{mode}/app-{size*scale}.png',dest)
                images.append({'filename':filename,'idiom':'mac','size':f'{size}x{size}','scale':f'{scale}x'})
            (catalog/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2)+'\n')
            subprocess.run(['iconutil','-c','icns',str(appset),'-o',str(OUT/f'macOS/{mode}/AppIcon.icns')],check=True)
            for name,(role,geometry) in GLYPHS.items():
                glyph=svg(f'<g fill="none" stroke="{p[role]}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{geometry}</g>',24,24)
                path=write(f'UI/{mode}/{name}.svg',glyph)
                render(path, OUT/f'UI/{mode}/{name}@2x.png',48)
            swatches=''.join(f'<rect x="{i%4*240}" y="{i//4*120}" width="220" height="65" rx="8" fill="{value}"/><text x="{i%4*240}" y="{i//4*120+89}" fill="{p["ink"]}" font-size="17" font-family="Helvetica Neue,Arial,sans-serif">{name} {value}</text>' for i,(name,value) in enumerate((k,v) for k,v in p.items() if k!='raised'))
            sheet=write(f'Palette/swatches-{mode}.svg',svg(f'<rect width="1000" height="580" fill="{p["bg"]}"/><g transform="translate(24 24)">{swatches}</g>',1000,580))
            render(sheet,OUT/f'Palette/swatches-{mode}.png',1600)
            gpl='GIMP Palette\nName: Frog Native Solarized '+mode.title()+'\nColumns: 4\n# Semantic palette, not raw canonical accents\n'
            for name,value in p.items():
                if name=='raised':continue
                gpl+=' '.join(str(int(value[i:i+2],16)) for i in [1,3,5])+'\t'+name+'\n'
            write(f'Palette/solarized-{mode}.gpl',gpl)
        template=write('Brand/frog-template.svg',svg(mark(colors['dark'],mono='#000000')))
        for size in [16,18,20,22,24,32,36,40,44,48]:render(template,OUT/f'macOS/Template/frog-{size}.png',size)
        for name,(_,geometry) in GLYPHS.items():
            write(f'UI/template/{name}.svg',svg(f'<g fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{geometry}</g>',24,24))
        write('Palette/tokens.json',json.dumps(colors,indent=2)+'\n')
        css='/* Generated from FileManagerTheme.swift. Dark is the default. */\n'
        for mode,p in colors.items():
            css+=(':root, [data-theme="solarized-dark"]' if mode=='dark' else '[data-theme="solarized-light"]')+' {\n'
            for name,value in p.items():
                if name=='raised':
                    for key,val in value.items():css+=f'  --frog-raised-{key}: {val};\n'
                else:css+=f'  --frog-{name}: {value};\n'
            css+='}\n'
        write('Palette/solarized.css',css)
        for token in [key for key in colors['dark'] if key!='raised']:
            entries=[]
            for mode in ['light','dark']:
                value=colors[mode][token]
                entry={'idiom':'universal','color':{'color-space':'srgb','components':{'red':f'0x{value[1:3]}','green':f'0x{value[3:5]}','blue':f'0x{value[5:7]}','alpha':'1.000'}}}
                if mode=='dark':entry['appearances']=[{'appearance':'luminosity','value':'dark'}]
                entries.append(entry)
            write(f'Palette/Solarized.xcassets/{token}.colorset/Contents.json',json.dumps({'colors':entries,'info':{'author':'xcode','version':1}},indent=2)+'\n')
        write('Palette/Solarized.xcassets/Contents.json',json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
        # Existing exporter location and conventional release resources remain compatible.
        for path in (OUT/'macOS/dark/AppIcon.iconset').iterdir():
            shutil.copyfile(path,OUT/'AppIcon.iconset'/path.name)
        shutil.copyfile(OUT/'macOS/dark/AppIcon.icns',ROOT/'Resources/AppIcon.icns')
        for name in ['app-icon-dark.svg','app-icon-dark-small.svg']:
            shutil.copyfile(OUT/'Source'/name,BRAND_RESOURCE/name)
        for size in [16,32,64,128,256,512,1024]:
            shutil.copyfile(OUT/f'Icons/dark/app-{size}.png',BRAND_RESOURCE/f'app-{size}.png')
        preview=f'<rect width="1600" height="1000" fill="{colors["dark"]["bg2"]}"/><text x="64" y="76" fill="{colors["dark"]["ink"]}" font-size="40" font-family="Helvetica Neue,Arial,sans-serif">Frog Native / Solarized Asset Kit</text>'
        for mode,x in [('dark',64),('light',840)]:
            p=colors[mode];preview+=f'<rect x="{x}" y="112" width="696" height="800" rx="24" fill="{p["bg"]}"/><text x="{x+32}" y="164" fill="{p["ink"]}" font-family="Helvetica Neue,Arial,sans-serif" font-size="24">Solarized {mode.title()}</text>'
            preview+=f'<g transform="translate({x+150} 180) scale(.38)">{mark(p)}</g>'
            for i,size in enumerate([16,32,64,128]):
                data=base64.b64encode((OUT/f'Icons/{mode}/app-{size}.png').read_bytes()).decode()
                preview+=f'<image x="{x+38+i*155}" y="600" width="{size}" height="{size}" href="data:image/png;base64,{data}"/>'
            for i,role in enumerate(['blue','good','warn','bad','cyan','violet']):
                preview+=f'<circle cx="{x+60+i*105}" cy="810" r="20" fill="{p[role]}"/>'
        preview_path=write('Preview/asset-board.svg',svg(preview,1600,1000));render(preview_path,OUT/'Preview/asset-board.png',1600)
        for mode,p in colors.items():
            board=f'<rect width="1000" height="760" fill="{p["bg"]}"/><text x="32" y="48" fill="{p["ink"]}" font-size="28" font-family="Helvetica Neue,Arial,sans-serif">Frog Native / {mode.title()} UI glyphs</text>'
            for index,(name,(role,geometry)) in enumerate(GLYPHS.items()):
                x=32+(index%5)*195;y=90+(index//5)*108
                board+=f'<g transform="translate({x+46} {y}) scale(2)" fill="none" stroke="{p[role]}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{geometry}</g><text x="{x}" y="{y+76}" fill="{p["ink2"]}" font-size="15" font-family="Helvetica Neue,Arial,sans-serif">{name}</text>'
            path=write(f'Preview/glyphs-{mode}.svg',svg(board,1000,760));render(path,OUT/f'Preview/glyphs-{mode}.png',1400)
    write('README.md',README)
    manifest=[]
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path.name!='asset-manifest.json':
            manifest.append({'path':str(path.relative_to(OUT)),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    write('asset-manifest.json',json.dumps({'files':manifest},indent=2)+'\n')
    archive=ROOT/'dist/FrogNative-AssetKit.zip';archive.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(OUT.rglob('*')):
            if path.is_file():
                entry=zipfile.ZipInfo(str(Path('FrogNative-AssetKit')/path.relative_to(OUT)),date_time=(2026,10,27,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED
                bundle.writestr(entry,path.read_bytes())
    print(f'Generated {len(manifest)+1} assets; archive: {archive}')


README='''# Frog Native — Solarized Asset Kit

Default: Solarized Dark. Light is an alternate asset family. The frog eyes and stepped folder front identify the file manager; the two lower panels echo its dual-pane layout. The small icon removes fine details at 16–32 px.

- `macOS/`: Dark/Light `.icns`, complete ten-image `.iconset`, Xcode app-icon catalogs, and monochrome menu-bar masks. Set `NSImage.isTemplate = true` for template PNGs; these are masks, not UI black fills.
- `Windows/`: multi-resolution ICO (16, 20, 24, 32, 40, 48, 64, 96, 128, 256 px).
- `Linux/`: hicolor PNG hierarchy and scalable SVG. Default app identifier: `frog-native`.
- `Web/`: SVG/ICO favicons, Apple touch icon, 192/512 PNGs, safe-zone maskable icon, and relative-path web manifests. Set deployment URLs in the consuming site.
- `Brand/`: transparent frog marks, monochrome marks, SVG/PNG wordmarks. Wordmark SVGs use Helvetica Neue with Arial/sans-serif fallback; PNG lockups are fixed. These are editable text, not outlined font artwork.
- `UI/`: 30 original 24-point glyphs, Dark/Light SVG and 2x PNG, plus `currentColor` templates. These are reusable exports; the native app continues using system symbols.
- `Palette/`: semantic JSON/CSS, GIMP palettes, visual swatches, and Xcode light/dark color assets. Raised-surface inks preserve the hover contrast corrections. The Swift theme is the color authority.
- `Source/`: editable app-icon vectors, standard/small/full-square. The full-square variant and foreground mark can be imported into Icon Composer; this kit does not claim to include a compiled layered Icon Composer project.
- `Preview/`: overview board. `asset-manifest.json` inventories files and SHA-256 hashes.

From the repository, run `python3 scripts/generate-assets.py` on macOS to regenerate, then `python3 scripts/validate-assets.py` to check the kit. It uses the system Swift/AppKit SVG renderer and `iconutil`, with no third-party packages. Generated assets and brand source follow the repository license. No Apple SF Symbol artwork is redistributed.

macOS release packaging uses the Dark ICNS. The app icon does not switch when the in-app Light theme is selected. Windows/Linux/web are export assets, not new platform application builds. No custom document associations or OS file-type defaults are registered.
'''

if __name__=='__main__':main()
