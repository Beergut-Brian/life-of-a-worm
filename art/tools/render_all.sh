#!/usr/bin/env bash
# Render the Godot preview frames for every look and shot into art/direction/<option>/.
#   art/tools/render_all.sh [a b c]
set -euo pipefail
cd "$(dirname "$0")/../.."
declare -A SLUG=([a]=a_arcade_chomp [b]=b_lantern_deep [c]=c_tall_tale)
for look in "${@:-a b c}"; do
  for look1 in $look; do
    out="art/direction/${SLUG[$look1]}"; mkdir -p "$out"
    for shot in xs planet dock; do
      tmp=".scratch/shots/$look1-$shot"; rm -rf "$tmp"; mkdir -p "$tmp"
      scripts/tools/shots.sh res://art/preview/preview.tscn 1.5 "$PWD/$tmp" --look="$look1" --shot="$shot" >/dev/null
      cp "$(ls "$tmp"/*.png | head -1)" "$out/${shot}.png"
      echo "$out/${shot}.png"
    done
  done
done
