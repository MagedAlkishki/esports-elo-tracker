/// Pure Elo rating math -- no player registry, no I/O, nothing stateful.
/// Kept separate from [EloTracker] specifically so it's trivially testable
/// on its own: every test here is "given these numbers, is the output
/// exactly this formula's result", with no setup beyond plain doubles.
library;

import 'dart:math' as math;

/// The outcome of a match from player A's perspective.
enum MatchResult { winA, winB, draw }

/// The standard Elo expected-score formula: the probability player A is
/// predicted to score against player B, purely from the rating gap.
/// Always in (0, 1); exactly 0.5 when the ratings are equal.
double expectedScore(double ratingA, double ratingB) {
  return 1.0 / (1.0 + math.pow(10, (ratingB - ratingA) / 400.0));
}

/// The actual score used in the Elo update formula: 1.0 for a win, 0.5
/// for a draw, 0.0 for a loss, all from player A's perspective.
double _actualScoreForA(MatchResult result) {
  switch (result) {
    case MatchResult.winA:
      return 1.0;
    case MatchResult.winB:
      return 0.0;
    case MatchResult.draw:
      return 0.5;
  }
}

/// A single player's rating and its change after one match -- the ratings
/// before/after AND how much it moved, so callers don't have to subtract.
class RatingUpdate {
  final double before;
  final double after;

  const RatingUpdate(this.before, this.after);

  double get delta => after - before;

  @override
  String toString() =>
      'RatingUpdate(before: ${before.toStringAsFixed(1)}, after: ${after.toStringAsFixed(1)}, '
      'delta: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)})';
}

/// Computes both players' new ratings after one match. [kFactor] controls
/// how much a single result can move a rating -- a common choice is 32
/// for newer/volatile players and something smaller (e.g. 16) once a
/// player's rating has stabilized, which is why it's a parameter here
/// rather than a hardcoded constant.
(RatingUpdate, RatingUpdate) applyMatchResult({
  required double ratingA,
  required double ratingB,
  required MatchResult result,
  double kFactor = 32,
}) {
  if (kFactor <= 0) {
    throw ArgumentError.value(kFactor, 'kFactor', 'must be positive');
  }

  final expectedA = expectedScore(ratingA, ratingB);
  final actualA = _actualScoreForA(result);
  // By symmetry, B's expected/actual scores are just 1 minus A's -- no
  // need for a second expectedScore(ratingB, ratingA) call.
  final expectedB = 1.0 - expectedA;
  final actualB = 1.0 - actualA;

  final newA = ratingA + kFactor * (actualA - expectedA);
  final newB = ratingB + kFactor * (actualB - expectedB);

  return (RatingUpdate(ratingA, newA), RatingUpdate(ratingB, newB));
}
