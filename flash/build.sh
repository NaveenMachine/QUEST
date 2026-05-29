#!/usr/bin/env bash
# Build quest_run.gif and quest_run_1200.gif from scene.html.
# Usage: ./build.sh           — full rebuild (install deps if needed, capture frames, encode both GIFs)
#        ./build.sh encode    — just re-encode existing /tmp/gif_build/frames into GIFs
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR=/tmp/gif_build
OUT_DIR="$(cd "$SRC_DIR/.." && pwd)"

mkdir -p "$BUILD_DIR/frames"
cp -f "$SRC_DIR/scene.html" "$SRC_DIR/capture.js" "$BUILD_DIR/"

# 1. install puppeteer-core if /tmp got wiped
if [ ! -d /tmp/node_modules/puppeteer-core ]; then
  echo ">> installing puppeteer-core"
  (cd /tmp && npm install --no-save --silent puppeteer-core@21)
fi

# 2. load ffmpeg module if not on PATH
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo ">> loading ffmpeg module"
  if command -v module >/dev/null 2>&1; then
    module load ffmpeg/6.1.1
  fi
fi

if [ "${1:-}" != "encode" ]; then
  echo ">> capturing frames with puppeteer (~1 min)"
  rm -f "$BUILD_DIR"/frames/*.png
  (cd "$BUILD_DIR" && node capture.js)
fi

cd "$BUILD_DIR"

# 3. high-quality 2x GIF (matches retina; ~2400x1350)
echo ">> encoding 2x GIF"
ffmpeg -y -framerate 18 -i frames/f%04d.png \
  -vf "palettegen=max_colors=200:reserve_transparent=0:stats_mode=full" \
  -frames:v 1 -update 1 palette.png -loglevel error
ffmpeg -y -framerate 18 -i frames/f%04d.png -i palette.png \
  -lavfi "[0:v][1:v]paletteuse=dither=floyd_steinberg:diff_mode=rectangle" \
  -r 18 quest_run.gif -loglevel error

# 4. standard 1x GIF (1200x675)
echo ">> encoding 1x GIF"
ffmpeg -y -framerate 18 -i frames/f%04d.png \
  -vf "scale=1200:-1:flags=lanczos,palettegen=max_colors=200:reserve_transparent=0:stats_mode=full" \
  -frames:v 1 -update 1 palette_1x.png -loglevel error
ffmpeg -y -framerate 18 -i frames/f%04d.png -i palette_1x.png \
  -lavfi "[0:v]scale=1200:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=floyd_steinberg:diff_mode=rectangle" \
  -r 18 quest_run_1200.gif -loglevel error

cp quest_run.gif quest_run_1200.gif "$OUT_DIR/"
echo ">> done"
ls -lh "$OUT_DIR"/quest_run*.gif
