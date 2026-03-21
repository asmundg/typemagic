# AGENTS.md — TypeMagic

> Full product specification (gameplay, scoring, tiers, achievements, etc.): **[spec.md](spec.md)**

## Project overview

TypeMagic is a **gamified Norwegian typing practice app** built with Flutter. Users type Norwegian sentences and words across progressive difficulty tiers while earning XP, unlocking achievements, and tracking detailed statistics. The app runs on macOS, web, and Windows.

## Tech stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart SDK ^3.11.1) |
| State management | Riverpod (flutter_riverpod + riverpod_annotation + riverpod_generator) |
| Routing | go_router (ShellRoute with fade transitions) |
| Persistence | Hive (test results, XP, achievements) + SharedPreferences (settings) |
| Charts | fl_chart |
| Audio | audioplayers |
| Fonts | google_fonts (JetBrains Mono for typing, Inter for UI) |
| Localization | intl (Norwegian nb_NO) |

## Architecture

```
lib/
├── main.dart                          # App entry, GoRouter config, nav shell
├── core/
│   ├── models.dart                    # Shared data models (TestConfig, TestResult, TestWord, etc.)
│   ├── theme.dart                     # 5 color themes, AppTheme / AppColors utilities
│   ├── audio_service.dart             # Sound effect playback (keystroke, error, level_up, …)
│   └── app_init.dart                  # Hive + intl initialization
├── features/
│   ├── typing_test/                   # Core typing test — input handling, live stats, results
│   ├── dictionary/                    # Tiered word loading, weak-word remediation
│   ├── sentence_gen/                  # Markov-chain sentence generation (trigram/bigram interpolated)
│   ├── progression/                   # XP/level system, tier unlocks, daily challenges
│   ├── achievements/                  # 20 achievements in 5 categories
│   ├── stats/                         # Historical stats, per-key accuracy, fl_chart visualizations
│   └── settings/                      # Theme, sound, gameplay preferences
└── widgets/
    ├── confetti_overlay.dart          # Celebration particle animation
    ├── xp_bar.dart                    # Compact XP progress indicator
    └── test_config_bar.dart           # Sentence count & tier selector
```

### Data flow

1. **Word selection** — `WordProvider` loads tiered JSON dictionaries, builds a weighted pool (current tier 3×), and injects weak words (20% chance).
2. **Sentence generation** — `SentenceGeneratorCore` uses interpolated trigram/bigram Markov chains with temperature scaling per tier to produce natural Norwegian sentences.
3. **Typing test** — `TypingTestNotifier` (Riverpod) tracks per-character state, computes live WPM/accuracy, and on completion persists results via `StatsRepository`.
4. **Progression** — `XPSystem` awards XP = floor(WPM × accuracy² × timeFactor), levels up, and unlocks higher tiers.
5. **Achievements** — `AchievementChecker` evaluates 20 unlock conditions after each test.

### Assets

- `assets/dictionaries/` — tier1–5.json (words with freq_rank, length, has_special flag)
- `assets/markov/` — trigrams, bigrams, and meta JSON for sentence generation
- `assets/sounds/` — keystroke, error, word_complete, test_complete, level_up, achievement (.mp3)
- `assets/images/` — reserved (empty)

### Tools

- `tools/preprocess/` — Python scripts to build dictionaries from Norsk Ordbank and train Markov models from Norwegian text corpora
- `tools/generate_examples.dart` — Dart script to generate example sentences for testing

## Development

```bash
# Run on macOS / Chrome
flutter run -d macos
flutter run -d chrome

# Code generation (Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Analysis
flutter analyze
```

## Validation

Always run `flutter analyze` after making code changes and before committing. The 3 pre-existing `info` diagnostics in `tools/generate_examples.dart` are known and acceptable — no other warnings or errors should be introduced.

## Conventions

- **Language:** All UI text is Norwegian. Code identifiers and comments are English.
- **State:** Feature state lives in Riverpod Notifiers under each feature directory. No global mutable singletons.
- **Models:** Immutable data classes in `core/models.dart` (with Equatable where needed).
- **Theming:** All colors go through `AppColors` / `AppTheme` — never hard-code color values in widgets.
- **Persistence:** Hive for structured data, SharedPreferences for flat key-value settings.
