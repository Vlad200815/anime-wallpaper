#!/bin/zsh
# Builds AnimeWallpaper.app next to this script.
set -euo pipefail
cd "${0:A:h}"

swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP=AnimeWallpaper.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/AnimeWallpaper" "$APP/Contents/MacOS/"
cp -R "$BIN/RiveRuntime.framework" "$APP/Contents/Frameworks/"
cp Sources/AnimeWallpaper/Resources/anime-girl.riv "$APP/Contents/Resources/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/AnimeWallpaper" 2>/dev/null || true

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AnimeWallpaper</string>
    <key>CFBundleDisplayName</key><string>Anime Wallpaper</string>
    <key>CFBundleIdentifier</key><string>local.animewallpaper</string>
    <key>CFBundleExecutable</key><string>AnimeWallpaper</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $PWD/$APP"
