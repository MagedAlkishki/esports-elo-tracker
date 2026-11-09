# esports-elo-tracker

An Elo rating tracker for competitive players, in Dart: a pure rating-math
library, a stateful tracker (player registry, shared match timeline,
head-to-head lookups, JSON persistence), and an interactive CLI on top.

## Why this exists

My other languages are Java, JavaScript, Python, PHP, C++, C#, and SQL;
Dart rounds those out, and an Elo tracker is a natural fit for both the
language and my background -- it's the exact rating system competitive
games (chess, and most ranked matchmaking systems, including the ones I
played under as a Valorant pro) are built on, and it's a good showcase
for Dart specifically: sound null safety throughout, a Dart 3 record type
as a lightweight return value (`(RatingUpdate, RatingUpdate)` instead of
a one-off wrapper class), `dart:convert`/`dart:io` for real JSON
persistence, and pattern-matching `switch` expressions.

## What it does

- Pure Elo math (`lib/elo_calculator.dart`): `expectedScore()` and
  `applyMatchResult()`, with zero dependency on the tracker or any
  player state -- given two ratings and a result, it just computes.
- A stateful tracker (`lib/elo_tracker.dart`): register players, record
  matches, a ranked leaderboard, per-player rating history over time,
  and head-to-head records between any two players.
- JSON persistence: `EloTracker.toJson()`/`fromJson()`, plus
  `saveToFile()`/`loadFromFile()` that actually hit disk via `dart:io`.
- An interactive CLI (`bin/main.dart`): `ADD`, `MATCH`, `LEADERBOARD`,
  `HISTORY`, `H2H`, `SAVE`, `LOAD`.

## Design notes

- **The rating math is pure and separate from the tracker on purpose.**
  `applyMatchResult()` takes two ratings and a result and returns two
  new ratings -- no player objects, no map lookups, no I/O. That's what
  makes `test/elo_calculator_test.dart` able to assert exact values
  (equal ratings, A wins, K=32 -> **exactly** +16.0/-16.0, not
  "approximately") instead of only approximate ones.
- **A shared match index, not a per-player one.** Every match increments
  one global counter on the tracker, and both participants' history
  points are stamped with that same index. That's what lets a player's
  rating history be compared against another's at the same point in the
  overall timeline, not just "their own Nth match."
- **A caught real bug during testing, not a hypothetical one:** Dart's
  `List` does not override `==` to compare elements -- two different
  list instances holding the same values are `!=` to each other (plain
  identity comparison, same as any other Object). My first pass at the
  leaderboard-ordering tests used plain `expectEqual()` on two lists and
  they failed with `expected [High, Mid, Low], got [High, Mid, Low]` --
  identical-looking output, failing anyway, which is exactly the
  confusing failure mode this bug produces. `test/test_harness.dart` has
  a dedicated `expectListEqual()` that does element-wise comparison
  (Dart's `collection` package has `ListEquality` for this, but pub.dev
  wasn't reachable in the sandbox this was built in -- see Testing below).

## Building and running

```bash
dart pub get
dart run bin/main.dart
```

```
esports-elo-tracker -- type HELP for commands.
> ADD Nimzer 1200
Registered Nimzer (1200.0)
> ADD Rixtov 1350
Registered Rixtov (1350.0)
> MATCH Nimzer Rixtov A
Nimzer: RatingUpdate(before: 1200.0, after: 1222.5, delta: +22.5)
Rixtov: RatingUpdate(before: 1350.0, after: 1327.5, delta: -22.5)
> LEADERBOARD
  1. Rixtov               1327.5
  2. Nimzer               1222.5
```

## Running the tests

```bash
dart run test/all_tests.dart
```

26 tests against the custom harness in `test/test_harness.dart` -- no
`package:test` (the standard Dart testing package), since this was built
in a sandbox with no network access to pub.dev to fetch it. Covers the
Elo formula itself (including an exact-value test, a zero-sum/conserved-
rating property across every result type, and a k-factor scaling check),
player registration and validation, match recording and the shared match
index, leaderboard ordering (including the List-equality issue above),
rating history, head-to-head from both query directions, and a full
JSON round-trip through actual files on disk (not just in-memory
objects).

## Project layout

```
lib/elo_calculator.dart    Pure Elo math: expectedScore(), applyMatchResult()
lib/models.dart              Player, RatingPoint, MatchRecord (+ JSON (de)serialization)
lib/elo_tracker.dart          The stateful tracker: registry, matches, leaderboard, H2H, persistence
bin/main.dart                  Interactive CLI
test/test_harness.dart         Minimal Dart test harness (no external dependency)
test/elo_calculator_test.dart   9 tests against the pure math
test/elo_tracker_test.dart       17 tests against the stateful tracker
test/all_tests.dart               Entry point: registers and runs everything
```
