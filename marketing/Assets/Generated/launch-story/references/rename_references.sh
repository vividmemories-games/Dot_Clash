#!/usr/bin/env bash
# Renames uploaded reference photos to father.jpg and son.jpg.
# Usage:
#   ./rename_references.sh              # auto-detect (larger file = father photo)
#   ./rename_references.sh father son   # explicit source filenames
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shopt -s nullglob

images=()
for f in "$DIR"/*; do
  base="$(basename "$f")"
  case "${base,,}" in
    readme.md|.gitkeep|father.jpg|son.jpg|father.jpeg|son.jpeg|father.png|son.png|rename_references.sh) continue ;;
  esac
  case "${base,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.heic) images+=("$f") ;;
  esac
done

if [[ $# -eq 2 ]]; then
  src_father="$DIR/$1"
  src_son="$DIR/$2"
  [[ -f "$src_father" ]] || { echo "Not found: $1" >&2; exit 1; }
  [[ -f "$src_son" ]] || { echo "Not found: $2" >&2; exit 1; }
elif [[ ${#images[@]} -eq 2 ]]; then
  # Default heuristic: larger file is usually the higher-res adult photo.
  if [[ $(stat -c%s "${images[0]}") -ge $(stat -c%s "${images[1]}") ]]; then
    src_father="${images[0]}"
    src_son="${images[1]}"
  else
    src_father="${images[1]}"
    src_son="${images[0]}"
  fi
  echo "Auto-detected:"
  echo "  father <- $(basename "$src_father")"
  echo "  son    <- $(basename "$src_son")"
else
  echo "Expected 2 image files in $DIR (any name)." >&2
  echo "Found: ${#images[@]}" >&2
  ls -la "$DIR" >&2
  exit 1
fi

ext_father="${src_father##*.}"
ext_son="${src_son##*.}"
[[ "${ext_father,,}" == "jpg" ]] && ext_father="jpg" || true
[[ "${ext_son,,}" == "jpg" ]] && ext_son="jpg" || true

rm -f "$DIR/father.jpg" "$DIR/son.jpg" "$DIR/father.jpeg" "$DIR/son.jpeg" "$DIR/father.png" "$DIR/son.png"
cp -- "$src_father" "$DIR/father.${ext_father,,}"
cp -- "$src_son" "$DIR/son.${ext_son,,}"

echo "Done:"
ls -lh "$DIR"/father.* "$DIR"/son.* 2>/dev/null || ls -lh "$DIR"
