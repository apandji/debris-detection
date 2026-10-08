#!/bin/sh
# Downloads the Core ML model into the app target. Without it the app falls back to MockDetector.
# The model is never committed (see .gitignore); releases are model-v0, model-v1, …
#   ios/fetch-model.sh          # model-v0
#   ios/fetch-model.sh v1
set -eu
VERSION="${1:-v0}"
DEST="$(cd "$(dirname "$0")" && pwd)/DebrisMapper/ML"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh release download "model-$VERSION" --repo apandji/debris-detection --dir "$TMP" \
  --pattern "DebrisDetector-$VERSION.mlpackage.zip" --pattern SHA256SUMS.txt
(cd "$TMP" && shasum -a 256 -c --ignore-missing SHA256SUMS.txt)
mkdir -p "$DEST"
rm -rf "$DEST/DebrisDetector.mlpackage"
unzip -q "$TMP/DebrisDetector-$VERSION.mlpackage.zip" -d "$TMP/unzipped"
mv "$(find "$TMP/unzipped" -name '*.mlpackage' -maxdepth 2 | head -1)" "$DEST/DebrisDetector.mlpackage"
echo "Installed DebrisDetector $VERSION in $DEST"
