#!/usr/bin/env bash
# Generate an EdDSA key pair for Sparkle update signing.
#
# Run this ONCE locally. Then:
# 1. Add the PRIVATE key as a GitHub Actions secret: SPARKLE_EDDSA_PRIVATE_KEY
# 2. Add the PUBLIC key to Info.plist under SUPublicEDKey
#
# The private key must NEVER be committed to the repository.

set -euo pipefail

echo "=== Sparkle EdDSA Key Generation ==="
echo ""

# Check if Sparkle's generate_keys is available
GENERATE_KEYS=""
if command -v generate_keys &> /dev/null; then
    GENERATE_KEYS="generate_keys"
elif [ -f ".build/artifacts/sparkle/Sparkle/bin/generate_keys" ]; then
    GENERATE_KEYS=".build/artifacts/sparkle/Sparkle/bin/generate_keys"
fi

if [ -n "$GENERATE_KEYS" ]; then
    echo "Using Sparkle's generate_keys tool..."
    $GENERATE_KEYS
    echo ""
    echo "Copy the public key to Info.plist (SUPublicEDKey)."
    echo "Store the private key as GitHub Actions secret SPARKLE_EDDSA_PRIVATE_KEY."
else
    echo "Sparkle's generate_keys tool not found."
    echo ""
    echo "To generate keys, first resolve SPM dependencies:"
    echo "  swift package resolve"
    echo ""
    echo "Then look for generate_keys in the Sparkle build artifacts, or"
    echo "download Sparkle from https://github.com/sparkle-project/Sparkle/releases"
    echo "and use the bin/generate_keys tool from the release package."
    echo ""
    echo "Alternative: generate manually with OpenSSL:"
    echo "  openssl genpkey -algorithm Ed25519 -out sparkle_private.pem"
    echo "  openssl pkey -in sparkle_private.pem -pubout -out sparkle_public.pem"
    echo ""
    echo "Then base64-encode the keys for use with Sparkle."
fi
