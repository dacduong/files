#!/usr/bin/env bash
set -euo pipefail

# Usage: decode_and_merge.sh <input_dir_with_txt> <output_zip_path>
# Example:
#   decode_and_merge.sh ./out ./recovered/my_archive.zip

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input_dir_with_txt> <output_zip_path>" >&2
  exit 1
fi

IN_DIR="$1"
OUT_ZIP="$2"
mkdir -p "$(dirname "$OUT_ZIP")"

# Collect *.txt files in numeric order into an array TXT_FILES[]
TXT_FILES=()

if compgen -G "$IN_DIR"/*.txt > /dev/null; then
  if sort -V </dev/null >/dev/null 2>&1; then
    for f in $(ls -1 "$IN_DIR"/*.txt | sort -V); do
      TXT_FILES+=("$f")
    done
  else
    # fallback numeric sort
    for f in $(ls -1 "$IN_DIR"/*.txt | awk '
      match($0, /(.*\.part)([0-9]+)\.txt$/, m){print m[2], $0}
    ' | sort -n | awk '{print $2}'); do
      TXT_FILES+=("$f")
    done
  fi
fi

if [[ ${#TXT_FILES[@]} -eq 0 ]]; then
  echo "Error: No .txt files found in '$IN_DIR'." >&2
  exit 1
fi

: > "$OUT_ZIP"
for f in "${TXT_FILES[@]}"; do
  base64 -d < "$f" >> "$OUT_ZIP"
done

echo "Reassembled ZIP: $OUT_ZIP"

SHA_FILE="$(ls -1 "$IN_DIR"/*.sha256 2>/dev/null | head -n 1 || true)"
if [[ -n "${SHA_FILE:-}" ]]; then
  if command -v shasum >/dev/null 2>&1; then
    echo "Verifying against $(basename "$SHA_FILE") ..."
    awk '{print $1}' "$SHA_FILE" | xargs -I{} shasum -a 256 "$OUT_ZIP"
  elif command -v sha256sum >/dev/null 2>&1; then
    echo "Verifying against $(basename "$SHA_FILE") ..."
    REF_HASH="$(awk '{print $1}' "$SHA_FILE")"
    ACT_HASH="$(sha256sum "$OUT_ZIP" | awk '{print $1}')"
    if [[ "$REF_HASH" == "$ACT_HASH" ]]; then
      echo "SHA-256 OK"
    else
      echo "WARNING: SHA-256 mismatch!" >&2
    fi
  fi
fi

echo "Done."
