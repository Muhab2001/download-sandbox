#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────
URL="${1:-}"
RULES_DIR="/rules"
DOWNLOAD_DIR="/sandbox"
OUTPUT_DIR="/output"
CLAM_DB_DIR="/var/lib/clamav"
SUMMARY=()
IS_INFECTED=0

if [[ -z "$URL" ]]; then
  echo "Usage: /scan.sh <URL>"
  exit 1
fi

echo "============================================================"
echo " 🛡️  Hardened Sandboxed File Scanner"
echo "============================================================"

# ── 1. Check DB Status ───────────────────────────────────────────
if [ -z "$(ls -A $CLAM_DB_DIR)" ]; then
    echo "⚠️  WARNING: ClamAV Database is empty!"
    echo "   Run 'make update-db' first."
    SUMMARY+=("Definitions: ❌ MISSING")
else
    DB_DATE=$(clamscan --version | cut -d'/' -f2 | cut -d' ' -f1)
    echo "[*] ClamAV DB Date: $DB_DATE"
fi

# ── 2. Download ──────────────────────────────────────────────────
echo "[*] Downloading: $URL"
wget --no-verbose --show-progress -P "$DOWNLOAD_DIR" "$URL" || { echo "Download failed!"; exit 1; }

FILENAME=$(basename "$URL" | sed 's/[^a-zA-Z0-9._-]//g')
FILEPATH="$DOWNLOAD_DIR/$FILENAME"
echo "[+] Saved to: $FILEPATH"

# ── 3. ClamAV Scan ───────────────────────────────────────────────
echo "------------------------------------------------------------"
echo " 🔍 ClamAV Scan"
echo "------------------------------------------------------------"
# Using clamscan (stand-alone).
if clamscan --infected --no-summary -d "$CLAM_DB_DIR" "$FILEPATH"; then
  SUMMARY+=("ClamAV:    ✅ CLEAN")
else
  SUMMARY+=("ClamAV:    ⚠️  THREAT DETECTED")
  IS_INFECTED=1
fi

# ── 4. Yara Scan ─────────────────────────────────────────────────
echo "------------------------------------------------------------"
echo " 🔍 Yara Rule Scan"
echo "------------------------------------------------------------"
YARA_HITS=0
if [[ -d "$RULES_DIR" ]] && [ "$(ls -A "$RULES_DIR")" ]; then
    while IFS= read -r -d '' rule; do
        RESULT=$(yara -w "$rule" "$FILEPATH")
        if [[ -n "$RESULT" ]]; then
            echo "$RESULT"
            YARA_HITS=$((YARA_HITS + 1))
        fi
    done < <(find "$RULES_DIR" \( -name "*.yar" -o -name "*.yara" \) -print0)

    if [[ $YARA_HITS -gt 0 ]]; then
        SUMMARY+=("Yara:      ⚠️  $YARA_HITS MATCHES FOUND")
        IS_INFECTED=1
    else
        SUMMARY+=("Yara:      ✅ CLEAN")
    fi
else
    SUMMARY+=("Yara:      ⏩ SKIPPED (No rules)")
fi

# ── 5. Summary & Extraction ──────────────────────────────────────
echo ""
echo "============================================================"
echo " 📊 SCAN SUMMARY"
echo "============================================================"
for line in "${SUMMARY[@]}"; do
  echo "  $line"
done
echo "============================================================"

if [[ $IS_INFECTED -eq 0 ]]; then
    echo "✅ File is clean."
    # Check if /output is mounted to host (writeable)
    if mount | grep "/output" > /dev/null; then
        echo "[*] Copying to safe output directory..."
        cp "$FILEPATH" "$OUTPUT_DIR/"
        echo "🎉 File available in your host 'safe_files' directory."
    else
        echo "ℹ️  Output volume not mounted. File will be discarded."
    fi
else
    echo "⛔ THREAT DETECTED. File will be destroyed."
    exit 1
fi
