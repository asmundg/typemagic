#!/usr/bin/env python3
"""
build_dictionary.py — Build tiered word dictionaries for TypeMagic.

Cross-references Norsk Ordbank (bokmål) with word frequency data to produce
five difficulty tiers of Norwegian words, each saved as a JSON file suitable
for the Flutter typing game.

Data sources:
  - Norsk Ordbank word list (one word per line, ~143k words)
  - Norwegian frequency list  (word + count per line, ~50k words)

Usage:
  python3 build_dictionary.py \
      --ordbank /tmp/nob_wordlist.txt \
      --freq    /tmp/no_freq_50k.txt \
      --output  ../../assets/dictionaries/
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from typing import Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

NORWEGIAN_SPECIAL = set("æøå")
# Only allow lowercase a-z plus æøå — no hyphens, digits, spaces, etc.
VALID_WORD_RE = re.compile(r"^[a-zæøå]+$")

# Profanity / inappropriate words to exclude (this is a kids' game!)
BLOCKED_WORDS = {
    # Norwegian swear words / vulgarities
    "faen", "jævla", "jævel", "jævlig", "helvete", "helvetes",
    "dritt", "drittunge", "drittsekk",
    "fitte", "fitta", "fittetransen",
    "pikk", "pikken", "kuken", "kuk", "kukk",
    "ræv", "ræva", "rassen",
    "hore", "hora", "horebukk",
    "knull", "knulle", "knullet", "knulling",
    "pule", "puling", "puler",
    "tull", # not profane but often misread
    # Sexual / adult content
    "sex", "sexy", "porno", "porn", "orgasme", "orgasmen",
    "penis", "vagina", "prostituert", "prostitusjon",
    # Slurs / derogatory
    "neger", "homo", "hæstkansen",
    "idiot", "idioten", "dåre",
    # Drug references
    "heroin", "kokain", "amfetamin",
}

# Each tier is (name, description, max_freq_rank, min_len, max_len, target_count)
# max_freq_rank=None means "no rank limit" (full dictionary).
# target_count is a soft cap — we keep up to this many words.
TIERS = [
    {
        "tier": 1,
        "name": "Nybegynner",
        "description": "Top 200 vanligste ord, 1-5 bokstaver",
        "max_freq_rank": 500,   # look within top-500 ranked words …
        "min_len": 1,
        "max_len": 5,
        "target_count": 200,    # … and keep up to 200
    },
    {
        "tier": 2,
        "name": "Lærling",
        "description": "Top 500 vanlige ord, 2-7 bokstaver",
        "max_freq_rank": 1500,
        "min_len": 2,
        "max_len": 7,
        "target_count": 500,
    },
    {
        "tier": 3,
        "name": "Ordsmith",
        "description": "Top 1500 ord, inkludert æ/ø/å-ord",
        "max_freq_rank": 5000,
        "min_len": 2,
        "max_len": None,        # no upper length limit
        "target_count": 1500,
    },
    {
        "tier": 4,
        "name": "Mester",
        "description": "Top 5000 ord, inkludert sammensatte ord",
        "max_freq_rank": 15000,
        "min_len": 2,
        "max_len": None,
        "target_count": 5000,
    },
    {
        "tier": 5,
        "name": "Trollmann",
        "description": "Hele ordboken — sjeldne og lange ord",
        "max_freq_rank": None,
        "min_len": 2,
        "max_len": None,
        "target_count": 10000,  # cap at 10k (was unlimited)
    },
]

# ---------------------------------------------------------------------------
# Loading helpers
# ---------------------------------------------------------------------------

def load_ordbank(path: str) -> "set[str]":
    """Return the set of valid words from the Ordbank word list."""
    words: set[str] = set()
    with open(path, encoding="utf-8") as f:
        for line in f:
            w = line.strip().lower()
            if VALID_WORD_RE.match(w) and w not in BLOCKED_WORDS:
                words.add(w)
    print(f"  Loaded {len(words):,} valid words from Ordbank ({path})")
    return words


def load_frequencies(path: str) -> "dict[str, int]":
    """Return {word: rank} from the frequency file (rank 1 = most frequent)."""
    freq: "dict[str, int]" = {}
    with open(path, encoding="utf-8") as f:
        for rank, line in enumerate(f, start=1):
            parts = line.strip().split()
            if len(parts) >= 1:
                w = parts[0].lower()
                if w not in freq:          # keep first (= highest) rank
                    freq[w] = rank
    print(f"  Loaded {len(freq):,} frequency entries ({path})")
    return freq

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def has_special(word: str) -> bool:
    return any(c in NORWEGIAN_SPECIAL for c in word)


def special_count(word: str) -> int:
    return sum(1 for c in word if c in NORWEGIAN_SPECIAL)


def difficulty_score(word: str, freq_rank: Optional[int], max_rank: int) -> float:
    """
    Compute a composite difficulty score (lower = easier).

    Components (all normalised to roughly 0-1 then weighted):
      - Frequency rank  (60 %): common words are easier
      - Word length     (25 %): shorter words are easier
      - Special chars   (15 %): æøå add difficulty for beginners
    """
    # Frequency component — unranked words get max_rank + 1
    rank = freq_rank if freq_rank is not None else (max_rank + 1)
    freq_component = rank / max_rank  # ~0-1, lower is easier

    # Length component — normalise against a "hard" length of 15
    len_component = min(len(word) / 15.0, 1.0)

    # Special-character component
    spec_component = min(special_count(word) / 3.0, 1.0)

    return 0.60 * freq_component + 0.25 * len_component + 0.15 * spec_component

# ---------------------------------------------------------------------------
# Tier building
# ---------------------------------------------------------------------------

def build_tier(
    tier_def: dict,
    ordbank: "set[str]",
    freq: "dict[str, int]",
    max_rank: int,
    already_used: "set[str]",
) -> "list[dict]":
    """Select words for one tier, return list of word-info dicts."""
    candidates = []

    for word in ordbank:
        if word in already_used:
            continue

        wlen = len(word)

        # Length filter
        if wlen < tier_def["min_len"]:
            continue
        if tier_def["max_len"] is not None and wlen > tier_def["max_len"]:
            continue

        freq_rank = freq.get(word)

        # Frequency rank filter (None = no limit)
        if tier_def["max_freq_rank"] is not None:
            if freq_rank is None or freq_rank > tier_def["max_freq_rank"]:
                continue

        score = difficulty_score(word, freq_rank, max_rank)

        candidates.append((score, {
            "word": word,
            "freq_rank": freq_rank,  # may be None for unranked words
            "length": wlen,
            "has_special": has_special(word),
        }))

    # Sort by difficulty score (easiest first)
    candidates.sort(key=lambda t: t[0])

    # Apply target_count cap
    limit = tier_def["target_count"]
    if limit is not None:
        candidates = candidates[:limit]

    return [entry for _, entry in candidates]

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def resolve_path(explicit: Optional[str], filenames: "list[str]") -> str:
    """Return *explicit* if given, otherwise search common locations."""
    if explicit:
        return explicit
    search_dirs = ["/tmp", os.path.expanduser("~/Downloads"), "."]
    for d in search_dirs:
        for fn in filenames:
            p = os.path.join(d, fn)
            if os.path.isfile(p):
                return p
    sys.exit(f"Could not find any of {filenames} — pass the path explicitly.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build tiered Norwegian word dictionaries for TypeMagic."
    )
    parser.add_argument(
        "--ordbank", default=None,
        help="Path to Norsk Ordbank word list (one word per line)."
    )
    parser.add_argument(
        "--freq", default=None,
        help="Path to frequency file (word + count per line)."
    )
    parser.add_argument(
        "--output", default=os.path.join(os.path.dirname(__file__), "..", "..", "assets", "dictionaries"),
        help="Output directory for JSON tier files (default: ../../assets/dictionaries/)."
    )
    args = parser.parse_args()

    ordbank_path = resolve_path(args.ordbank, ["nob_wordlist.txt"])
    freq_path    = resolve_path(args.freq,    ["no_freq_50k.txt"])
    output_dir   = os.path.abspath(args.output)
    os.makedirs(output_dir, exist_ok=True)

    print("=== TypeMagic Dictionary Builder ===\n")

    # 1. Load sources
    print("Loading data sources …")
    ordbank = load_ordbank(ordbank_path)
    freq    = load_frequencies(freq_path)
    max_rank = max(freq.values()) if freq else 50000

    # Include high-frequency words even if they're not in the Ordbank.
    # These are very common function words (er, har, kan, …) that may be
    # absent from dictionary word lists but are essential for typing practice.
    freq_supplement = {
        w for w, rank in freq.items()
        if rank <= 500 and VALID_WORD_RE.match(w) and w not in BLOCKED_WORDS
    }
    supplement_count = len(freq_supplement - ordbank)
    ordbank = ordbank | freq_supplement
    if supplement_count:
        print(f"  Added {supplement_count} high-frequency words not in Ordbank")

    # 2. Build tiers (each tier's words are exclusive — no duplicates across tiers)
    print("\nBuilding tiers …")
    already_used: set[str] = set()
    tier_outputs: list[dict] = []
    meta_tiers: list[dict] = []

    for tier_def in TIERS:
        words = build_tier(tier_def, ordbank, freq, max_rank, already_used)

        # Mark words as used so lower tiers don't repeat them
        already_used.update(w["word"] for w in words)

        tier_data = {
            "tier": tier_def["tier"],
            "name": tier_def["name"],
            "description": tier_def["description"],
            "words": words,
        }
        tier_outputs.append(tier_data)

        filename = f"tier{tier_def['tier']}.json"
        meta_tiers.append({
            "tier": tier_def["tier"],
            "name": tier_def["name"],
            "word_count": len(words),
            "file": filename,
        })

        print(f"  Tier {tier_def['tier']} ({tier_def['name']}): {len(words):,} words")

    # 3. Write tier JSON files
    print(f"\nWriting output to {output_dir} …")
    for tier_data in tier_outputs:
        filename = f"tier{tier_data['tier']}.json"
        filepath = os.path.join(output_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(tier_data, f, ensure_ascii=False, indent=2)
        print(f"  ✓ {filename}")

    # 4. Write metadata
    total_words = sum(t["word_count"] for t in meta_tiers)
    meta = {
        "tiers": meta_tiers,
        "total_words": total_words,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    meta_path = os.path.join(output_dir, "tiers_meta.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"  ✓ tiers_meta.json")

    print(f"\nDone — {total_words:,} words across {len(TIERS)} tiers.\n")


if __name__ == "__main__":
    main()
