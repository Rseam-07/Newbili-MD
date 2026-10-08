#!/usr/bin/env bash
set -euo pipefail
# Compile against public declarations only. Old SDK builds remain useful, with
# live size-class resizing and the manual tabletop layout, and say so explicitly.
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
OUTPUT="$ROOT_DIR/AndroidFlutter/ios/Flutter/NewbiliDuo.generated.xcconfig"
if python3 - "$SDK_VERSION" <<'PY'
import sys
v = tuple(int(x) for x in sys.argv[1].split('.'))
sys.exit(0 if v >= (27, 1) else 1)
PY
then
  # Availability alone is not sufficient: ensure the installed SDK has the API.
  PROBE="$(mktemp -d "${TMPDIR:-/tmp}/newbili-duo-sdk.XXXXXX")"
  trap 'rm -rf "$PROBE"' EXIT
  cat > "$PROBE/probe.swift" <<'SWIFT'
import UIKit
@available(iOS 27.1, *) @MainActor
func probe(_ view: UIView) {
  _ = view.reservedRegions(kind: .division, options: .includeInactive)
  _ = view.reservedRegions(kind: .occlusion)
  _ = view.traitCollection.verticalBarEdge
  view.addInteraction(UIHingeInteraction { _, _ in })
}
SWIFT
  xcrun swiftc -typecheck -sdk "$SDK_PATH" -target arm64-apple-ios27.1 "$PROBE/probe.swift"
  printf '%s\n' 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) NEWBILI_DUO_SDK' > "$OUTPUT"
  echo "Duo native regions: enabled (SDK $SDK_VERSION, public API probe passed)"
else
  printf '%s\n' '// Native Duo APIs require iOS SDK 27.1; responsive geometry and manual tabletop remain enabled.' > "$OUTPUT"
  echo "Duo native regions: unavailable in SDK $SDK_VERSION; using responsive/manual fallback"
fi
