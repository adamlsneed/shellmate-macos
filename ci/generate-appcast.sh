#!/usr/bin/env bash
# Generate Sparkle appcast.xml for a release.
# Usage: generate-appcast.sh <dmg-path> <version> <build-number>
#
# Requires:
#   - SPARKLE_PRIVATE_KEY env var (EdDSA private key for signing)
#   - Sparkle's sign_update tool (optional, for EdDSA signature)

set -euo pipefail

DMG_PATH="$1"
VERSION="$2"
BUILD_NUMBER="$3"

if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: DMG not found at $DMG_PATH"
    exit 1
fi

DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_FILENAME=$(basename "$DMG_PATH")
RELEASE_URL="https://github.com/adamlsneed/shellmate-macos/releases/download/v${VERSION}/${DMG_FILENAME}"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

# Generate EdDSA signature if private key is available
EDDSA_SIGNATURE=""
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    # Write private key to temp file for signing
    KEYFILE=$(mktemp)
    echo "$SPARKLE_PRIVATE_KEY" > "$KEYFILE"

    # Try to use Sparkle's sign_update tool if available
    if command -v sign_update &> /dev/null; then
        EDDSA_SIGNATURE=$(sign_update "$DMG_PATH" --ed-key-file "$KEYFILE" 2>/dev/null || echo "")
    elif [ -f ".build/artifacts/sparkle/Sparkle/bin/sign_update" ]; then
        EDDSA_SIGNATURE=$(.build/artifacts/sparkle/Sparkle/bin/sign_update "$DMG_PATH" --ed-key-file "$KEYFILE" 2>/dev/null || echo "")
    fi

    rm -f "$KEYFILE"
fi

# Build the enclosure attributes
ENCLOSURE_ATTRS="url=\"${RELEASE_URL}\" length=\"${DMG_SIZE}\" type=\"application/octet-stream\""
if [ -n "$EDDSA_SIGNATURE" ]; then
    ENCLOSURE_ATTRS="${ENCLOSURE_ATTRS} sparkle:edSignature=\"${EDDSA_SIGNATURE}\""
fi

# Generate appcast XML
mkdir -p build
cat > "build/appcast.xml" << APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Shellmate Updates</title>
    <link>https://github.com/adamlsneed/shellmate-macos/releases</link>
    <description>Shellmate app updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure ${ENCLOSURE_ATTRS} />
    </item>
  </channel>
</rss>
APPCAST

echo "Generated appcast.xml for v${VERSION} (build ${BUILD_NUMBER})"
echo "  DMG: ${DMG_FILENAME} (${DMG_SIZE} bytes)"
echo "  URL: ${RELEASE_URL}"
if [ -n "$EDDSA_SIGNATURE" ]; then
    echo "  EdDSA signature: present"
else
    echo "  WARNING: No EdDSA signature (SPARKLE_PRIVATE_KEY not set or sign_update not found)"
fi
