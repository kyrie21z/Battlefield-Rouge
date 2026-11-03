#!/usr/bin/env bash
# Installs the pinned Godot (standard, not .NET) for the review VM and warms the
# import cache. Used by .cursor/environment.json; safe to run again.
set -eu
VERSION="4.7.2-stable"
FILE="Godot_v${VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${FILE}.zip"
# From the release's SHA512-SUMS.txt.
SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
DIR="$HOME/.local/godot/$VERSION"
BIN="$HOME/.local/bin/godot"

if [ ! -x "$DIR/$FILE" ]; then
	mkdir -p "$DIR"
	tmp="$(mktemp -d)"
	curl -sSLf -o "$tmp/godot.zip" "$URL"
	echo "$SHA512  $tmp/godot.zip" | sha512sum -c -
	python3 -I -m zipfile -e "$tmp/godot.zip" "$DIR"
	chmod +x "$DIR/$FILE"
	rm -rf "$tmp"
fi
mkdir -p "$(dirname "$BIN")"
ln -sf "$DIR/$FILE" "$BIN"
"$BIN" --version

# Warm .godot/ so the first review does not pay for the import.
cd "$(git rev-parse --show-toplevel)"
"$BIN" --headless --import --path . > /dev/null 2>&1 || true
