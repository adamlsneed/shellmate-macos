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

# Generate EdDSA signature if private key is available.
# Hard-fail (rather than silently ship an unsigned appcast) if the key is set
# but signing can't run — Sparkle refuses unsigned updates when SUPublicEDKey
# is configured, so a silent miss means auto-update is broken for every user.
EDDSA_SIGNATURE=""
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    # Locate sign_update: $PATH first, then anywhere under .build/artifacts
    # (the exact SPM path varies between Sparkle versions).
    SIGN_UPDATE=$(command -v sign_update 2>/dev/null || true)
    if [ -z "$SIGN_UPDATE" ]; then
        SIGN_UPDATE=$(find .build/artifacts -name sign_update -type f -perm +111 2>/dev/null | head -1 || true)
    fi
    if [ -z "$SIGN_UPDATE" ]; then
        echo "::error::SPARKLE_PRIVATE_KEY is set but sign_update is not on PATH and not under .build/artifacts. Auto-update would silently break."
        exit 1
    fi
    echo "Using sign_update at: $SIGN_UPDATE"

    # Write private key to temp file. Use printf — `echo` appends a newline
    # which sign_update's --ed-key-file does not tolerate.
    KEYFILE=$(mktemp)
    chmod 600 "$KEYFILE"
    # shellcheck disable=SC2059
    printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEYFILE"

    # Run sign_update without swallowing errors — capture stderr so we can
    # report a real failure cause if signing fails.
    if ! EDDSA_SIGNATURE=$("$SIGN_UPDATE" "$DMG_PATH" --ed-key-file "$KEYFILE" 2>"$KEYFILE.err"); then
        SIGN_ERR=$(cat "$KEYFILE.err")
        rm -f "$KEYFILE" "$KEYFILE.err"
        echo "::error::sign_update failed: $SIGN_ERR"
        exit 1
    fi
    rm -f "$KEYFILE" "$KEYFILE.err"

    if [ -z "$EDDSA_SIGNATURE" ]; then
        echo "::error::sign_update returned an empty signature"
        exit 1
    fi
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
    echo "  WARNING: No EdDSA signature (SPARKLE_PRIVATE_KEY not set — auto-update will not work for users)"
fi
