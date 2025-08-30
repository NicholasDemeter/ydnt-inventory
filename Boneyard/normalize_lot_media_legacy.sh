#!/bin/bash
# Compatible with macOS /bin/bash 3.2 (no mapfile, no associative arrays)
# Usage:
#   bash ./normalize_lot_media_legacy.sh           # dry run
#   DRY_RUN=0 bash ./normalize_lot_media_legacy.sh # apply changes
set -euo pipefail

: "${DRY_RUN:=1}"
IMG_EXTS="jpg jpeg png webp heic heif tif tiff JPG JPEG PNG WEBP HEIC HEIF TIF TIFF"
VID_EXTS="mp4 mov m4v avi mkv MP4 MOV M4V AVI MKV"

say() { printf "%s\n" "$*"; }
doit() { if [ "${DRY_RUN}" = "0" ]; then eval "$*"; else say "[DRY-RUN] $*"; fi; }

is_in_list() {
  ext="$1"; list="$2"
  for e in $list; do [ "$ext" = "$e" ] && return 0; done
  return 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

IM_CMD=""
if have_cmd magick; then IM_CMD="magick"
elif have_cmd convert; then IM_CMD="convert"
fi

if ! have_cmd awk || ! have_cmd find || ! have_cmd xargs || ! have_cmd stat; then
  say "ERROR: This script requires awk, find, xargs, and stat."; exit 1
fi

[ -n "$IM_CMD" ] || say "WARNING: ImageMagick not found (magick/convert). Photo -> .jpg conversion will be skipped."

say "Mode: $( [ "$DRY_RUN" = "1" ] && echo DRY-RUN || echo APPLY )"

# 1) Deduplicate by exact byte size within Photos/ and Videos/
say "Step 1: Deduplicate by exact byte size within each LOT's Photos/ and Videos/"
find . -maxdepth 1 -type d -name "LOT_*" -print0 | while IFS= read -r -d '' lotdir; do
  for sub in Photos Videos; do
    subdir="${lotdir}/${sub}"; [ -d "$subdir" ] || continue
    say "  ├─ ${subdir}"
    tmp="$(mktemp)"
    find "$subdir" -type f ! -name ".*" -print0 | while IFS= read -r -d '' f; do
      size="$(stat -f "%z" "$f" 2>/dev/null || stat -c "%s" "$f" 2>/dev/null || echo 0)"
      printf "%s\t%s\n" "$size" "$f" >> "$tmp"
    done
    if [ -s "$tmp" ]; then
      awk -F'\t' '{
        sz=$1; p=$2;
        if (count[sz]++) { print p; }
      }' <(sort -n -k1,1 "$tmp") | while IFS= read -r dup; do
        ds=$(stat -f "%z" "$dup" 2>/dev/null || stat -c "%s" "$dup" 2>/dev/null || echo 0)
        say "      dup(${ds}) => rm: $dup"
        doit "rm -f \"\$dup\""
      done
    fi
    rm -f "$tmp"
  done
done

# 2) Convert photos to .jpg (videos unchanged)
if [ -n "$IM_CMD" ]; then
  say "Step 2: Convert photos to .jpg"
  pred=""
  for e in $IMG_EXTS; do
    [ -z "$pred" ] && pred="-iname '*.$e'" || pred="$pred -o -iname '*.$e'"
  done
  eval find . -type f \( $pred \) -print0 | while IFS= read -r -d '' img; do
    ext="${img##*.}"
    if [ "$ext" != "jpg" ] && [ "$ext" != "JPG" ]; then
      out="${img%.*}.jpg"
      say "  convert: $img -> $out"
      doit "$IM_CMD \"\$img\" -auto-orient -quality 88 \"\$out\""
      [ "$DRY_RUN" = "0" ] && rm -f -- "$img"
    fi
  done
else
  say "Step 2 skipped (no ImageMagick)."
fi

# 3) Normalize names -> LOT_###_<index>.<ext>
say "Step 3: Rename files to strip extra info -> LOT_###_<index>.<ext>"
find . -type f -path "./LOT_*/*" ! -name ".*" -print0 | while IFS= read -r -d '' f; do
  base="$(basename "$f")"; dir="$(dirname "$f")"; ext="${base##*.}"
  idx="$(printf "%s" "$base" | sed -E 's/\.[^.]+$//' | grep -Eo '[0-9]+' | tail -n1)"
  lot_from_name="$(printf "%s" "$base" | grep -Eo 'LOT_[0-9]{3}' | head -n1)"
  lot_from_path="$(printf "%s" "$dir"  | grep -Eo 'LOT_[0-9]{3}' | tail -n1)"
  lot="${lot_from_name:-$lot_from_path}"

  if [ -z "${lot:-}" ] || [ -z "${idx:-}" ]; then
    say "  skip (no LOT or index): $f"; continue
  fi

  lower_ext="$(printf "%s" "$ext" | tr 'A-Z' 'a-z')"
  newext="$lower_ext"
  if is_in_list "$lower_ext" "$IMG_EXTS"; then newext="jpg"
  elif is_in_list "$lower_ext" "$VID_EXTS"; then newext="$lower_ext"
  fi

  target="${dir}/${lot}_${idx}.${newext}"
  if [ -e "$target" ] && [ "$target" != "$f" ]; then
    n=1; while [ -e "${dir}/${lot}_${idx}_${n}.${newext}" ]; do n=$((n+1)); done
    target="${dir}/${lot}_${idx}_${n}.${newext}"
  fi

  if [ "$f" != "$target" ]; then
    say "  mv: $f -> $target"
    doit "mv -f \"\$f\" \"\$target\""
  fi
done

say "Done. Re-run with DRY_RUN=0 to apply changes:"
say "  DRY_RUN=0 bash ./normalize_lot_media_legacy.sh"
