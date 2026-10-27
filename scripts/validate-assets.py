#!/usr/bin/env python3
"""Validate generated asset formats, sizes, referenced files, and inventory hashes."""
from pathlib import Path
import hashlib
import json
import plistlib
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'Assets'


def png_size(data):
    assert data[:8]==b'\x89PNG\r\n\x1a\n', 'Invalid PNG signature'
    width,height,depth,kind=struct.unpack('>IIBB',data[16:26])
    assert depth==8 and kind==6, 'Expected 8-bit RGBA'
    offset=8; chunks=[]
    while offset<len(data):
        length=struct.unpack('>I',data[offset:offset+4])[0]
        chunks.append(data[offset+4:offset+8]);offset+=12+length
    assert b'sRGB' in chunks or b'iCCP' in chunks, 'Missing color profile'
    return width,height


def main():
    inventory=json.loads((ASSETS/'asset-manifest.json').read_text())['files']
    expected={entry['path'] for entry in inventory}
    actual={str(p.relative_to(ASSETS)) for p in ASSETS.rglob('*') if p.is_file() and p.name!='asset-manifest.json'}
    assert expected==actual, 'Manifest must cover every asset exactly'
    pngs=svgs=icos=0
    for entry in inventory:
        path=ASSETS/entry['path'];data=path.read_bytes()
        assert hashlib.sha256(data).hexdigest()==entry['sha256'], f'Stale asset: {path}'
        assert len(data)==entry['bytes']
        if path.suffix=='.png':
            png_size(data);pngs+=1
        elif path.suffix=='.svg':
            assert ET.fromstring(data).tag.endswith('svg');svgs+=1
        elif path.suffix=='.ico':
            reserved,kind,count=struct.unpack('<HHH',data[:6]);assert reserved==0 and kind==1
            sizes=set()
            for i in range(count):
                width,height,_,_,planes,bits,length,offset=struct.unpack('<BBBBHHII',data[6+16*i:22+16*i])
                size=(width or 256,height or 256);assert planes==1 and bits==32
                assert png_size(data[offset:offset+length])==size
                sizes.add(size[0])
            required={16,20,24,32,40,48,64,96,128,256} if 'Windows' in path.parts else {16,32,48}
            assert sizes==required,f'Incomplete ICO: {path}'
            icos+=1
        elif path.name=='Contents.json':
            catalog=json.loads(data)
            for image in catalog.get('images',[]):
                scale=int(image['scale'][0]);size=int(image['size'].split('x')[0])*scale
                assert png_size((path.parent/image['filename']).read_bytes())==(size,size)
        elif path.suffix=='.webmanifest':
            for icon in json.loads(data)['icons']:
                width,height=map(int,icon['sizes'].split('x'))
                assert png_size((path.parent/icon['src']).read_bytes())==(width,height)
    for mode in ['dark','light']:
        for size in [16,20,24,32,40,48,64,96,128,256,512,1024]:
            assert png_size((ASSETS/f'Icons/{mode}/app-{size}.png').read_bytes())==(size,size)
        with tempfile.TemporaryDirectory(prefix='frog-icns-check-') as temp:
            dest=Path(temp)/'Decoded.iconset'
            subprocess.run(['iconutil','-c','iconset',str(ASSETS/f'macOS/{mode}/AppIcon.icns'),'-o',str(dest)],check=True)
            assert len(list(dest.glob('*.png')))==10
    info=plistlib.loads((ROOT/'Resources/Info.plist').read_bytes())
    assert (ROOT/'Resources'/f'{info["CFBundleIconFile"]}.icns').is_file()
    assert (ROOT/'Resources/AppIcon.icns').read_bytes()==(ASSETS/'macOS/dark/AppIcon.icns').read_bytes()
    with zipfile.ZipFile(ROOT/'dist/FrogNative-AssetKit.zip') as archive:
        assert archive.testzip() is None
        assert len(archive.namelist())==len(inventory)+1
    print(f'Validated {len(inventory)+1} files: {pngs} PNG, {svgs} SVG, {icos} ICO; both ICNS round trips, catalogs, manifests, archive, and release icon passed.')


if __name__=='__main__':main()
