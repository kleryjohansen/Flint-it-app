#!/bin/bash
# Bersihin derived data + cache build biar entitlements ga kotor
# Jalanin ini tiap kali kamu ganti entitlements atau sebelum build ulang

DERIVED=~/Library/Developer/Xcode/DerivedData

echo "🧹 Cleaning derived data..."
rm -rf "$DERIVED"

# Uninstall app dari simulator kalo kamu pakai simulator
xcrun simctl shutdown all 2>/dev/null
xcrun simctl erase all 2>/dev/null

echo "✅ Done. Build ulang sekarang."
