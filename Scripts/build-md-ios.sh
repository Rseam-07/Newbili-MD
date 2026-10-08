#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/AndroidFlutter"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter)}"
MODE="${1:-simulator}"
TARGET="${MD_IOS_TARGET:-lib/main.dart}"

if [[ "$MODE" != simulator && "$MODE" != unsigned ]]; then
  echo "Usage: $0 [simulator|unsigned]" >&2
  exit 2
fi

# A Documents/iCloud checkout can attach Finder metadata to built frameworks,
# which codesign correctly rejects. Keep generated artifacts outside that tree.
if [[ -n "${MD_IOS_BUILD_DIR:-}" ]]; then
  mkdir -p "$MD_IOS_BUILD_DIR"
  if [[ -e "$APP_DIR/build" || -L "$APP_DIR/build" ]]; then
    if [[ "$(cd "$APP_DIR/build" && pwd -P)" != "$(cd "$MD_IOS_BUILD_DIR" && pwd -P)" ]]; then
      echo "Move the existing AndroidFlutter/build directory before using MD_IOS_BUILD_DIR." >&2
      exit 1
    fi
  else
    ln -s "$(cd "$MD_IOS_BUILD_DIR" && pwd -P)" "$APP_DIR/build"
  fi
fi

VERSION="$(sed -n 's/^version: //p' "$APP_DIR/pubspec.yaml" | head -n 1)"
IOS_BUILD_NUMBER="${VERSION##*+}"
[[ "$IOS_BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid iOS build number" >&2; exit 1; }
ARGS=(--no-pub "--target=$TARGET" "--build-name=${VERSION%%+*}" "--build-number=$IOS_BUILD_NUMBER" "--dart-define=pili.name=${VERSION%%+*}"
  "--dart-define=pili.code=${VERSION##*+}" "--dart-define=pili.hash=$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)"
  "--dart-define=pili.time=$(date +%s)")
cd "$APP_DIR"
bash "$ROOT_DIR/Scripts/configure-duo-sdk.sh"
if [[ "$MODE" == simulator ]]; then
  # Keep ad-hoc signing enabled: media_kit's embedded libraries must be signed
  # even on the simulator, or dyld terminates the app before Dart starts.
  "$FLUTTER_BIN" build ios --simulator --debug "${ARGS[@]}"
  codesign --verify --deep --strict build/ios/iphonesimulator/Runner.app
else
  "$FLUTTER_BIN" build ios --release --no-codesign "${ARGS[@]}"
  OUTPUT_DIR="$ROOT_DIR/dist"
  mkdir -p "$OUTPUT_DIR"
  STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/newbili-md-ipa.XXXXXX")"
  trap 'rm -rf "$STAGING_DIR"' EXIT
  mkdir -p "$STAGING_DIR/Payload"
  COPYFILE_DISABLE=1 ditto --norsrc --noextattr build/ios/iphoneos/Runner.app "$STAGING_DIR/Payload/Runner.app"
  IPA_PATH="$OUTPUT_DIR/Newbili-MD-${VERSION/+/-}-iOS-unsigned.ipa"
  (cd "$STAGING_DIR" && COPYFILE_DISABLE=1 zip -q -r candidate.ipa Payload)
  mv "$STAGING_DIR/candidate.ipa" "$IPA_PATH"
  shasum -a 256 "$IPA_PATH"
  echo "Unsigned IPA (requires your own signing): $IPA_PATH"
fi
