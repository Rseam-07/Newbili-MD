#!/usr/bin/env python3
"""Render static download links and hashes from the exact packaged APK files."""
import argparse
import hashlib
import html
import json
import re
from datetime import date
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--pending', action='store_true', help='Local design preview only; all downloads remain disabled')
parser.add_argument('--date', default=date.today().isoformat())
args = parser.parse_args()
version, build = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)', (root / 'AndroidFlutter/pubspec.yaml').read_text(), re.M).groups()
base = 'https://rseam-07.github.io/downloads/files/'
release = f'https://github.com/Rseam-07/Newbili-MD/releases/download/v{version}/'
values = {'version': version, 'build': build, 'date': args.date, 'date_display': args.date.replace('-', '.'), 'download_label': '官网直链下载' if not args.pending else '安装包正在构建'}
assets = []
for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64'):
    name = f'Newbili-MD-{version}-{build}-{abi}.apk'
    path = root / 'dist' / name
    if args.pending:
        values.update({f'size_{abi}': '待发布', f'sha_{abi}': '安装包发布后提供', f'download_{abi}': 'aria-disabled="true"', f'fallback_{abi}': 'aria-disabled="true"'})
        continue
    digest = hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()
    size = path.stat().st_size
    if size > 100 * 1024 * 1024:
        raise SystemExit(f'{name} exceeds GitHub ordinary file limit; configure an artifact origin before publishing.')
    values.update({f'size_{abi}': f'{size / 1024 / 1024:.1f} MB', f'sha_{abi}': digest, f'download_{abi}': f'href="{html.escape(base + name)}" download="{name}" data-apk', f'fallback_{abi}': f'href="{html.escape(release + name)}"'})
    assets.append({'abi': abi, 'name': name, 'bytes': size, 'sha256': digest, 'url': base + name, 'githubUrl': release + name})
page = (root / 'Website/downloads.template.html').read_text()
for key, value in values.items():
    page = page.replace('{{' + key + '}}', str(value))
if re.search(r'{{.+?}}', page):
    raise SystemExit('Unresolved download page variables')
(root / 'Website/dist/downloads/index.html').write_text(page)
manifest = {'version': version, 'build': int(build), 'date': args.date, 'channel': 'preview', 'minAndroid': '12', 'ready': not args.pending, 'assets': assets}
(root / 'Website/dist/releases.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
if assets:
    (root / 'dist' / f'SHA256SUMS-{version}.txt').write_text(''.join(f'{a["sha256"]}  {a["name"]}\n' for a in assets))
print(f'Download page: {version} ({build}), {len(assets)} verified files')
