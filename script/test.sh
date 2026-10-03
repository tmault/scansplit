#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
SWIFT_BIN="$(xcrun --find swiftc)"
PLUGIN="$(dirname "$SWIFT_BIN")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$PLUGIN" ]]; then
  swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" "$@"
else
  swift test --disable-xctest "$@"
fi
