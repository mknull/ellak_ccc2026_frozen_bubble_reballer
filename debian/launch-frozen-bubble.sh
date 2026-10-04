#!/usr/bin/env bash
# Debian/Ubuntu. Launch a Frozen Bubble session with a webcam snapshot as a ball:
# declare a color, snapshot the webcam, tint the snapshot into that ball, play.
# Usage: bash launch-frozen-bubble.sh COLOR
# COLOR: a CSS color name, '#RRGGBB', or an exact ball slot (1..8).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT=/tmp/frozen-bubble-ball.jpg
GAME=/usr/games/frozen-bubble

usage() {
    cat <<EOF
Usage: bash launch-frozen-bubble.sh COLOR

Snapshot the webcam, replace the matching Frozen Bubble ball (and its
miniature) with the tinted snapshot, then launch the game.

COLOR      CSS color name (e.g. red), '#RRGGBB', or ball slot 1..8.
           Names select the closest original ball's hue for the tint.

The game must be closed while the ball is replaced; this script starts it
afterwards. The replacement step needs write access to the asset directory
and prompts for sudo if required. Originals are kept as FILE.original.

Dependencies: fswebcam, python3-pil, frozen-bubble.
EOF
}

if [ "$#" -ne 1 ]; then
    usage >&2
    exit 1
fi
case "$1" in -h|--help) usage; exit 0;; esac
color=$1

command -v fswebcam >/dev/null || {
    echo 'fswebcam is required: sudo apt-get install fswebcam' >&2; exit 1; }
[ -x "$GAME" ] || {
    echo "Frozen Bubble not found at $GAME" >&2; exit 1; }

echo "Snapshotting webcam to $SNAPSHOT..."
fswebcam --no-banner -r 1280x720 "$SNAPSHOT"

echo "Replacing ball with tinted snapshot (color: $color)..."
sudo bash "$SCRIPT_DIR/replace-frozen-bubble.sh" "$SNAPSHOT" "$color"

exec "$GAME"
