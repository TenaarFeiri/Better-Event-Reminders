#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_NAME="BetterEventReminders"
TOC_FILE="$ROOT_DIR/$ADDON_NAME.toc"
RELEASE_DIR="$ROOT_DIR/.release"
STAGE_DIR="$RELEASE_DIR/stage/$ADDON_NAME"
VERSION="$(awk -F': ' '/^## Version:/{print $2; exit}' "$TOC_FILE")"

if [[ -z "$VERSION" ]]; then
    echo "Could not read version from $TOC_FILE" >&2
    exit 1
fi

OUTPUT="$RELEASE_DIR/${ADDON_NAME}-${VERSION}.zip"

rm -rf "$RELEASE_DIR"
mkdir -p "$STAGE_DIR"

cp "$ROOT_DIR"/*.lua "$STAGE_DIR/"
cp "$TOC_FILE" "$STAGE_DIR/"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/"

(
    cd "$RELEASE_DIR/stage"
    zip -r -q "$OUTPUT" "$ADDON_NAME"
)

echo "Successfully staged $ADDON_NAME v$VERSION"
echo "Archive: $OUTPUT"
echo "Size: $(du -h "$OUTPUT" | awk '{print $1}')"
echo "Contents:"
unzip -l "$OUTPUT" | sed -n '1,20p'
