#!/usr/bin/env python3
"""Publish matching Android/iOS downloads from the exact packaged files."""
import argparse
import hashlib
import html
import json
import plistlib
import re
import zipfile
from datetime import date
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--pending', action='store_true', help='Local design preview only; all downloads remain disabled')
parser.add_argument('--date', default=date.today().isoformat())
parser.add_argument('--tag', help='GitHub release tag; defaults to vVERSION-build.BUILD')
parser.add_argument('--require-native-duo', action='store_true', help='Reject an IPA without compiled native Duo bridge symbols')
parser.add_argument('--duo-pose-report', type=Path, help='Attach the actual simulator posture validation report')
args = parser.parse_args()
pose_report = json.loads(args.duo_pose_report.read_text()) if args.duo_pose_report else None
pose_validated = bool(pose_report and pose_report.get('nativeSimulatorPosesPassed'))
version, build = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)', (root / 'AndroidFlutter/pubspec.yaml').read_text(), re.M).groups()
if pose_report and pose_report.get('unifiedVersion') != f'{version}+{build}':
    raise SystemExit('Duo posture report does not match the release version')
base = 'https://rseam-07.github.io/downloads/files/'
tag = args.tag or f'v{version}-build.{build}'
if not re.fullmatch(r'[A-Za-z0-9._-]+', tag):
    raise SystemExit('Invalid release tag')
release_page = f'https://github.com/Rseam-07/Newbili-MD/releases/tag/{tag}'
release = f'https://github.com/Rseam-07/Newbili-MD/releases/download/{tag}/'
values = {'version': version, 'build': build, 'date': args.date, 'date_display': args.date.replace('-', '.'), 'release_url': release_page, 'download_label': '官网直链下载' if not args.pending else '安装包正在构建'}
assets = []
for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64'):
    name = f'Newbili-MD-{version}-{build}-{abi}.apk'
    path = root / 'dist' / name
    if args.pending:
        values.update({f'size_{abi}': '待发布', f'sha_{abi}': '安装包发布后提供', f'download_{abi}': 'aria-disabled="true"', f'fallback_{abi}': 'aria-disabled="true"'})
        continue
    with path.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    size = path.stat().st_size
    if size > 100 * 1024 * 1024:
        raise SystemExit(f'{name} exceeds GitHub ordinary file limit; configure an artifact origin before publishing.')
    values.update({f'size_{abi}': f'{size / 1024 / 1024:.1f} MB', f'sha_{abi}': digest, f'download_{abi}': f'href="{html.escape(base + name)}" download="{name}" data-apk', f'fallback_{abi}': f'href="{html.escape(release + name)}"'})
    assets.append({'abi': abi, 'name': name, 'bytes': size, 'sha256': digest, 'url': base + name, 'githubUrl': release + name})

# Shared updates are released together. A missing or stale IPA must not silently
# leave iOS on an older build while the download page advertises a new release.
ios_asset = None
ios_name = f'Newbili-MD-{version}-{build}-iOS-unsigned.ipa'
if args.pending:
    values.update({'download_ios': 'aria-disabled="true"', 'size_ios': '待发布',
                   'ios_duo_change': 'iOS 原生折叠桥接正在构建验证。',
                   'ios_duo_boundary': '安装包正在构建，原生能力与设备验收结果待发布。'})
else:
    ios_path = root / 'dist' / ios_name
    with zipfile.ZipFile(ios_path) as ipa:
        info = plistlib.loads(ipa.read('Payload/Runner.app/Info.plist'))
        runner = ipa.read('Payload/Runner.app/Runner')
    native_duo = all(symbol in runner for symbol in
                     (b'UIHingeInteraction', b'reservedRegions', b'verticalBarEdge'))
    if args.require_native_duo and not native_duo:
        raise SystemExit('IPA does not contain the compiled native Duo bridge')
    if (info.get('CFBundleIdentifier') != 'com.rseam07.newbili.md'
            or info.get('CFBundleShortVersionString') != version
            or info.get('CFBundleVersion') != build):
        raise SystemExit('IPA identity or version does not match the Android release')
    with ios_path.open('rb') as source:
        ios_digest = hashlib.file_digest(source, 'sha256').hexdigest()
    ios_size = ios_path.stat().st_size
    if ios_size > 100 * 1024 * 1024:
        raise SystemExit('IPA exceeds the website ordinary file limit')
    ios_asset = {'name': ios_name, 'bytes': ios_size, 'sha256': ios_digest,
                 'url': base + ios_name, 'githubUrl': release + ios_name,
                 'requiresSigning': True, 'minIOS': info['MinimumOSVersion'],
                 'sdk': info.get('DTSDKName'), 'nativeDuoApiEnabled': native_duo}
    values.update({'download_ios': f'href="{html.escape(base + ios_name)}" download="{ios_name}"',
                   'size_ios': f'{ios_size / 1024 / 1024:.1f} MB',
                   'ios_duo_change': ('iOS 27.1 起按系统折叠区域、铰链与边缘导航变化调整布局，使用新 SDK 编译。'
                                      if native_duo else 'iOS 保留动态窗口与手动桌面观看，当前安装包未启用原生 Duo 桥接。'),
                   'ios_duo_boundary': (('Duo 原生桥接已启用；iOS 27.1 Duo 模拟器已验证书本、桌面、全屏、展开和合拢外屏保持同一播放器与解码器。真机功耗、帧时间与系统分屏仍待验收。IPA 需要自行签名。'
                                        if pose_validated else 'Duo 原生桥接已启用；已完成 SDK 与编译校验，模拟器姿态行为和真机播放仍待验收。较旧系统保留动态窗口与手动桌面观看。IPA 需要自行签名。')
                                        if native_duo else '当前 iOS 预览包支持动态窗口和手动桌面观看，尚未启用原生 Duo 识别。IPA 需要自行签名。')})

page = (root / 'Website/downloads.template.html').read_text()
for key, value in values.items():
    page = page.replace('{{' + key + '}}', str(value))
if re.search(r'{{.+?}}', page):
    raise SystemExit('Unresolved download page variables')
(root / 'Website/dist/downloads/index.html').write_text(page)
manifest = {'version': version, 'build': int(build), 'date': args.date, 'tag': tag, 'channel': 'preview', 'minAndroid': '12', 'ready': not args.pending, 'assets': assets, 'ios': ios_asset}
if ios_asset and pose_validated:
    ios_asset['duoSimulatorPoseValidation'] = 'passed'
(root / 'Website/dist/releases.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
if assets:
    (root / 'dist' / f'SHA256SUMS-{version}-build{build}.txt').write_text(''.join(f'{a["sha256"]}  {a["name"]}\n' for a in [*assets, ios_asset]))
print(f'Download page: {version} ({build}), {len(assets)} APKs and {int(ios_asset is not None)} IPA verified')
