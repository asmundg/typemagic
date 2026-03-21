# TypeMagic — Product & Technical Specification

## 1. Product concept

TypeMagic is a typing practice game optimized for **Norwegian text**, with special attention to the characters **æ, ø, å**. It combines the feel of competitive typing tests (like Monkeytype) with RPG-style progression — levels, tier unlocks, achievements, and daily challenges.

### Target platforms

macOS, Web, Windows (Flutter multi-platform).

### Target users

Norwegian speakers who want to improve typing speed and accuracy, from beginners through advanced typists.

---

## 2. Core gameplay loop

```
Choose tier/config → Type sentences → See results → Earn XP → Level up → Unlock harder tiers → Repeat
```

### Test modes

| Mode | Description |
|------|-------------|
| **Sentences** | Type a configurable number of generated Norwegian sentences (default: 3) |

> Time and word-count modes are defined in the data model but not yet exposed in the UI.

### Typing mechanics

- Characters are typed one at a time against a target sentence.
- Each character is immediately marked **correct** or **incorrect** (CharState).
- **Backspace** undoes the last character; navigates back to the previous word if at position 0.
- **Space** completes the current word and advances to the next.
- **Tab / Esc** restarts the test.
- The test finishes when the last character of the last word is typed.

### Scoring

| Metric | Formula |
|--------|---------|
| **WPM** | (correct_chars ÷ 5) ÷ minutes |
| **Raw WPM** | (total_chars ÷ 5) ÷ minutes |
| **Accuracy** | correct_chars ÷ total_chars × 100 |
| **Consistency** | (1 − σ/μ of per-word WPM) × 100 |

---

## 3. Difficulty tiers

Five tiers gate content by vocabulary difficulty. Higher tiers unlock as the user levels up.

| # | Name | Unlock level | Description |
|---|------|-------------|-------------|
| 1 | Nybegynner | 1 | ~500 common short words |
| 2 | Lærling | 5 | ~1 000 common words, slightly longer |
| 3 | Ordsmith | 10 | Words featuring æ, ø, å |
| 4 | Mester | 20 | Compound words |
| 5 | Trollmann | 35 | Full vocabulary |

### Word selection algorithm

1. Load all dictionaries up to the selected tier.
2. Weight the current tier 3× in the pool.
3. Avoid consecutive duplicates (10 retries).
4. 20% chance to inject a "weak word" — a word the user has previously mistyped.
5. **Special character focus** mode: filter pool to words containing æ/ø/å only.

---

## 4. Sentence generation

Sentences are produced by an **interpolated Markov chain** trained on Norwegian text.

### Model

- **Trigrams** (P = 0.7) + **Bigrams** (P = 0.2) with smoothing.
- Temperature scales with tier: 0.6 (tier 1, predictable) → 1.0 (tier 5, creative).
- Sentence length bounds per tier (e.g., tier 1: 4–8 words, tier 5: 6–20 words).

### Generation process

1. Pick a random starting bigram from the meta starters list.
2. Sample the next word from interpolated trigram/bigram probabilities.
3. Apply **vocabulary constraint**: words in the tier dictionary get 20× boost; out-of-vocabulary words are dampened to 0.05×.
4. Stop probabilistically when an ender word is reached.
5. Validate: reject if word repeats 3×, any word > 25 chars, or sentence < minWords.
6. Generate up to 3 candidates and pick the best-scoring one.

### Assets

| File | Contents |
|------|----------|
| `markov_trigrams.json` | `{ "w1 w2": [["w3", prob], …] }` |
| `markov_bigrams.json` | `{ "w1": [["w2", prob], …] }` |
| `markov_meta.json` | `{ starters: [[w1, w2], …], enders: [[w, prob], …] }` |

---

## 5. Progression system

### XP & levels

| Component | Formula |
|-----------|---------|
| **XP earned** | `floor(WPM × accuracy² × timeFactor)` |
| **XP for level N** | `floor(100 × N^1.5)` |

**Time factor** by test duration:

| Duration | Factor |
|----------|--------|
| ≤ 15 s | 0.5 |
| 16–30 s | 0.8 |
| 31–60 s | 1.0 |
| 61–120 s | 1.3 |
| > 120 s | 1.3 |

### Milestone titles

| Level | Title | Tier unlocked |
|-------|-------|--------------|
| 1 | Tastatur-troll | 1 |
| 5 | Bokstav-bull | 2 |
| 10 | Ordsmith | 3 |
| 20 | Runemester | 4 |
| 35 | Lynfinger | 5 |
| 50 | Stormskriver | — |
| 75 | Skrivekongen | — |

### Daily challenge

- **25 words** generated deterministically from the date (seeded RNG).
- Words drawn from cumulative vocabulary up to the player's unlocked tier.
- Completing the daily challenge awards **1.5× XP**.
- **Streak tracking**: +1 per consecutive day; resets if a day is missed.

---

## 6. Achievements

20 achievements across 5 categories, checked after every completed test.

### Speed 🏎

| Achievement | Condition |
|------------|-----------|
| Snegle | ≥ 10 WPM |
| Supersonisk | ≥ 80 WPM |
| Mach 10 | ≥ 100 WPM |

### Accuracy 🎯

| Achievement | Condition |
|------------|-----------|
| Skarpskytt | ≥ 95% accuracy |
| Perfeksjonist | 100% accuracy |
| Feilfri 10 | 10 tests with ≥ 98% accuracy |

### Streaks 🔥

| Achievement | Condition |
|------------|-----------|
| Tre på rad | 3-day streak |
| Månedlig | 30-day streak |
| Ustoppelig | 100-day streak |

### Volume 📚

| Achievement | Condition |
|------------|-----------|
| Første ord | 1 word typed |
| Hundre tusen | 100 000 words typed |

### Special 🌙

| Achievement | Condition |
|------------|-----------|
| Nattugle | Test completed after 22:00 |
| Tidlig fugl | Test completed before 07:00 |
| Helgekrigeren | Test completed on a weekend |
| Æ-Ø-Å Mester | Test in special-character-focus mode |
| Maraton | Test lasting ≥ 120 seconds |
| Ordbok-leser | 1 000 unique words typed |

---

## 7. Statistics

### Persisted data

Every `TestResult` is saved to Hive with: WPM, raw WPM, accuracy, consistency, character counts, word results, per-key stats, config, and timestamp.

### Aggregations

| View | Data |
|------|------|
| **Overview cards** | Total tests, total time, total words, average WPM, average accuracy |
| **Daily stats** | Per-day averages (WPM, accuracy, test count) for chart display |
| **Charts** | WPM and accuracy over time (7 / 30 / all-time range selector) |
| **Per-key heatmap** | Accuracy per keyboard key (correct / incorrect / total) |
| **Recent history** | Last 50 tests in a scrollable table |
| **Personal bests** | Best WPM per test mode |

---

## 8. Themes

Five built-in color themes, selectable in settings:

| ID | Name | Vibe |
|----|------|------|
| `dark` | Dark (default) | Navy background, gold accent |
| `light` | Light | White background, warm brown accent |
| `northern_lights` | Northern Lights | Deep blue, cyan/aurora accent |
| `fjord_blue` | Fjord Blue | Slate, Nordic blue accent |
| `viking_gold` | Viking Gold | Dark brown, gold accent |

Each theme defines: background layers, text hierarchy, typing feedback colors (correct/incorrect/extra/cursor), stat line colors, medal colors, and XP bar colors.

---

## 9. Audio

Six sound effects, all `.mp3`:

| Sound | Trigger | Volume |
|-------|---------|--------|
| `keystroke` | Every character typed | 0.3 |
| `error` | Incorrect character | 0.5 |
| `word_complete` | Word finished | 0.4 |
| `test_complete` | Test finished | 1.0 |
| `level_up` | Level gained | 1.0 |
| `achievement` | Achievement unlocked | 1.0 |

Audio can be toggled and volume-adjusted in settings.

---

## 10. Settings

| Setting | Key | Values | Default |
|---------|-----|--------|---------|
| Theme | `themeId` | dark, light, northern_lights, fjord_blue, viking_gold | dark |
| Sound enabled | `soundEnabled` | bool | true |
| Sound volume | `soundVolume` | 0.0–1.0 | 0.7 |
| Stop on error | `stopOnError` | off, letter, word | off |
| Default test mode | `defaultTestMode` | time, words, sentences | sentences |
| Default test value | `defaultTestValue` | int | 3 |
| Default tier | `defaultTier` | 1–5 | 1 |
| Font size | `fontSize` | small, medium, large | medium |

Persisted via SharedPreferences. Reset-all available in settings screen.

---

## 11. Data persistence

| Store | Engine | Contents |
|-------|--------|----------|
| `test_results` | Hive box | All TestResult objects |
| `xp_state` | Hive box | totalXP, currentLevel, currentTitle, unlockedTier |
| `achievements` | Hive box | Achievement unlock states + timestamps |
| `daily_challenge` | Hive box | Streak, last completion date, word list |
| `settings_*` | SharedPreferences | All AppSettings fields |

---

## 12. Preprocessing tools

Located in `tools/`:

| Tool | Purpose |
|------|---------|
| `tools/preprocess/` | Python scripts to build tiered dictionaries from Norsk Ordbank and train Markov models from Norwegian text corpora |
| `tools/generate_examples.dart` | Dart script to generate and preview example sentences from the Markov model |
