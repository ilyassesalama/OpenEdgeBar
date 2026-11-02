#!/bin/zsh
# Builds OpenEdgeBar.app into build/. Pass --install to copy it to /Applications and open it.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild \
  -project OpenEdgeBar.xcodeproj \
  -scheme OpenEdgeBar \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  -quiet \
  build

app=build/DerivedData/Build/Products/Release/OpenEdgeBar.app
rm -rf build/OpenEdgeBar.app
cp -R "$app" build/OpenEdgeBar.app
echo "Built build/OpenEdgeBar.app"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x OpenEdgeBar 2>/dev/null || true
  rm -rf /Applications/OpenEdgeBar.app
  cp -R build/OpenEdgeBar.app /Applications/OpenEdgeBar.app
  open /Applications/OpenEdgeBar.app
  echo "Installed to /Applications and opened"
fi
