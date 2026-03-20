#!/usr/bin/env bash
#
# download_nb_ngrams.sh — Download NB Språkbanken n-gram corpus (bokmål).
#
# Downloads the full Norsk Ordbank n-gram archive from Nasjonalbiblioteket
# using chunked range requests (server drops long connections), extracts only
# the bigram and trigram files needed for the Markov model, and cleans up.
#
# Source: https://www.nb.no/sprakbanken/ressurskatalog/oai-nb-no-sbr-12/
# License: CC0 (public domain)
#
# Usage:
#   ./download_nb_ngrams.sh [output-dir]
#   # Default output-dir: /tmp/nb_ngrams
#
# After running, build the Markov model with:
#   python3 build_markov_model.py --ngram-dir /tmp/nb_ngrams --output ../../assets/markov/

set -euo pipefail

URL="https://www.nb.no/sbfil/tekst/ngram_nob.tar.gz"
OUTDIR="${1:-/tmp/nb_ngrams}"
ARCHIVE="/tmp/ngram_nob.tar.gz"
CHUNK_SIZE=$((256 * 1024 * 1024))  # 256 MB chunks

# Get total file size
TOTAL=$(curl -sI "$URL" | grep -i content-length | awk '{print $2}' | tr -d '\r')
echo "=== NB N-gram Corpus Downloader ==="
echo "  Source:  $URL"
echo "  Size:    $(( TOTAL / 1048576 )) MB"
echo "  Output:  $OUTDIR"
echo ""

mkdir -p "$OUTDIR"

# Resume-aware chunked download
CURRENT=0
if [ -f "$ARCHIVE" ]; then
    CURRENT=$(stat -f%z "$ARCHIVE" 2>/dev/null || stat -c%s "$ARCHIVE" 2>/dev/null || echo 0)
    echo "Resuming from $(( CURRENT / 1048576 )) MB …"
fi

while [ "$CURRENT" -lt "$TOTAL" ]; do
    END=$(( CURRENT + CHUNK_SIZE - 1 ))
    if [ "$END" -ge "$TOTAL" ]; then
        END=$(( TOTAL - 1 ))
    fi

    echo "  Downloading bytes $((CURRENT / 1048576))–$((END / 1048576)) MB  ($(( (CURRENT * 100) / TOTAL ))%)"

    for attempt in 1 2 3 4 5; do
        if curl -sS -L --range "${CURRENT}-${END}" -o /tmp/_ngram_chunk "$URL"; then
            cat /tmp/_ngram_chunk >> "$ARCHIVE"
            rm -f /tmp/_ngram_chunk
            break
        fi
        echo "    Retry $attempt …"
        sleep $(( attempt * 2 ))
    done

    CURRENT=$(stat -f%z "$ARCHIVE" 2>/dev/null || stat -c%s "$ARCHIVE" 2>/dev/null)
done

echo ""
echo "Download complete: $(ls -lh "$ARCHIVE" | awk '{print $5}')"
echo ""
echo "Extracting bigram and trigram files …"

# List archive contents to find the 2-gram and 3-gram files
FILES=$(tar -tzf "$ARCHIVE" 2>/dev/null | grep -E '(ngram[23]|[23]-?gram)' || true)
if [ -z "$FILES" ]; then
    echo "  No 2/3-gram files found by name. Listing all contents:"
    tar -tzf "$ARCHIVE"
    exit 1
fi

echo "  Found: $FILES"
tar -xzf "$ARCHIVE" -C "$OUTDIR" --strip-components=1 $FILES

# Convert from Latin-1 to UTF-8 (NB corpus uses ISO-8859-1)
for f in "$OUTDIR"/*; do
    if file "$f" | grep -qi "iso-8859\|latin"; then
        echo "  Converting $(basename "$f") to UTF-8"
        iconv -f latin1 -t utf8 "$f" > "$f.utf8" && mv "$f.utf8" "$f"
    fi
done

# Rename to the format expected by build_markov_model.py
for f in "$OUTDIR"/*; do
    base=$(basename "$f")
    case "$base" in
        *2*gram*) [ "$base" != "2-gram.txt" ] && mv "$f" "$OUTDIR/2-gram.txt" ;;
        *3*gram*) [ "$base" != "3-gram.txt" ] && mv "$f" "$OUTDIR/3-gram.txt" ;;
    esac
done

echo ""
echo "Done. Files in $OUTDIR:"
ls -lh "$OUTDIR/"
echo ""
echo "Next step:"
echo "  cd $(dirname "$0")"
echo "  python3 build_markov_model.py --ngram-dir $OUTDIR --output ../../assets/markov/ --assets-dir ../../assets"
