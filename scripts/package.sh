#!/usr/bin/env bash
# Packages the NeededUtilities/ addon folder into a versioned zip under dist/.
# The version is read from the .toc so there's a single source of truth.
set -euo pipefail

cd "$(dirname "$0")/.."

TOC_FILE="NeededUtilities/NeededUtilities.toc"
VERSION=$(grep -m1 '^## Version:' "$TOC_FILE" | sed 's/^## Version:[[:space:]]*//')

if [ -z "$VERSION" ]; then
	echo "Could not read version from $TOC_FILE" >&2
	exit 1
fi

OUT_DIR="dist"
OUT_FILE="$OUT_DIR/NeededUtilities-${VERSION}.zip"

mkdir -p "$OUT_DIR"
rm -f "$OUT_FILE"

zip -r "$OUT_FILE" NeededUtilities \
	-x '*.DS_Store' \
	-x '*/.git/*'

echo "Packaged $OUT_FILE"
