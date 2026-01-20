#!/bin/bash
# install.sh - Build and install WhatsApp Privacy Blur as a proper macOS app

set -e

APP_NAME="WhatsApp Privacy Blur"
BUNDLE_NAME="$APP_NAME.app"
INSTALL_PATH="/Applications/$BUNDLE_NAME"
BUILD_CONFIG="release"

echo "Building $APP_NAME..."
swift build -c $BUILD_CONFIG

echo "Creating app bundle structure..."
rm -rf "$INSTALL_PATH"
mkdir -p "$INSTALL_PATH/Contents/MacOS"
mkdir -p "$INSTALL_PATH/Contents/Resources"

echo "Copying binary..."
cp ".build/$BUILD_CONFIG/HideWhatsApp" "$INSTALL_PATH/Contents/MacOS/HideWhatsApp"

echo "Copying Info.plist..."
cp "Info.plist" "$INSTALL_PATH/Contents/Info.plist"

# Add CFBundleExecutable to Info.plist if not present
if ! grep -q "CFBundleExecutable" "$INSTALL_PATH/Contents/Info.plist"; then
    sed -i '' 's|</dict>|    <key>CFBundleExecutable</key>\n    <string>HideWhatsApp</string>\n</dict>|' "$INSTALL_PATH/Contents/Info.plist"
fi

echo "Setting permissions..."
chmod +x "$INSTALL_PATH/Contents/MacOS/HideWhatsApp"

echo ""
echo "✓ Installed to: $INSTALL_PATH"
echo ""

# Ask to open
read -p "Open $APP_NAME now? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Launching..."
    open "$INSTALL_PATH"
fi
