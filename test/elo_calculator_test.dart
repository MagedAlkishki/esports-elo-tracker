import 'package:esports_elo_tracker/elo_calculator.dart';

import 'test_harness.dart';

void registerEloCalculatorTests() {
  TestHarness.test('expectedScore is exactly 0.5 for equal ratings', () {
    TestHarness.expectClose(expectedScore(1200, 1200), 0.5, 1e-9);
  });

  TestHarness.test('expectedScore favors the higher-rated player', () {
    TestHarness.expectTrue(expectedScore(1600, 1400) > 0.5);
    TestHarness.expectTrue(expectedScore(1400, 1600) < 0.5);
  });

  TestHarness.test('expectedScore for A and B are complementary (sum to 1)', () {
    final eA = expectedScore(1550, 1420);
    final eB = expectedScore(1420, 1550);
    TestHarness.expectClose(eA + eB, 1.0, 1e-9);
  });

  TestHarness.test('equal ratings, A wins: +16/-16 at K=32 (exact, no rounding)', () {
    final (updateA, updateB) =
        applyMatchResult(ratingA: 1200, ratingB: 1200, result: MatchResult.winA);
    TestHarness.expectEqual(updateA.after, 1216.0, 'winner new rating');
    TestHarness.expectEqual(updateB.after, 1184.0, 'loser new rating');
    TestHarness.expectEqual(updateA.delta, 16.0);
    TestHarness.expectEqual(updateB.delta, -16.0);
  });

  TestHarness.test('equal ratings, draw: both ratings stay exactly the same', () {
    final (updateA, updateB) =
        applyMatchResult(ratingA: 1000, ratingB: 1000, result: MatchResult.draw, kFactor: 16);
    TestHarness.expectEqual(updateA.after, 1000.0);
    TestHarness.expectEqual(updateB.after, 1000.0);
  });

  TestHarness.test('favorite beats underdog: both ratings barely move', () {
    // A=1600 (favorite) beats B=1400 (underdog) -- values cross-checked
    // against an independent Python implementation of the same formula.
    final (updateA, updateB) =
        applyMatchResult(ratingA: 1600, ratingB: 1400, result: MatchResult.winA);
    TestHarness.expectClose(updateA.after, 1607.688, 0.001, 'favorite win -> small gain');
    TestHarness.expectClose(updateB.after, 1392.312, 0.001, 'favorite win -> small loss');
  });

  TestHarness.test('underdog upset: both ratings swing hard', () {
    // A=1000 (huge underdog) beats B=1600 (huge favorite).
    final (updateA, updateB) =
        applyMatchResult(ratingA: 1000, ratingB: 1600, result: MatchResult.winA);
    TestHarness.expectClose(updateA.after, 1031.019, 0.001, 'upset win -> big gain');
    TestHarness.expectClose(updateB.after, 1568.981, 0.001, 'upset loss -> big drop');
    // The upset winner's gain should be much larger than the equal-rated
    // win's +16 -- that's the entire point of Elo over a flat points system.
    TestHarness.expectTrue(updateA.delta > 16.0);
  });

  TestHarness.test('total rating in the pool is conserved (zero-sum) for any result', () {
    for (final result in MatchResult.values) {
      final (updateA, updateB) =
          applyMatchResult(ratingA: 1337, ratingB: 1500, result: result, kFactor: 24);
      TestHarness.expectClose(updateA.delta + updateB.delta, 0.0, 1e-9, 'zero-sum: $result');
    }
  });

  TestHarness.test('kFactor scales the rating swing proportionally', () {
    final (lowK, _) =
        applyMatchResult(ratingA: 1200, ratingB: 1200, result: MatchResult.winA, kFactor: 16);
    final (highK, _) =
        applyMatchResult(ratingA: 1200, ratingB: 1200, result: MatchResult.winA, kFactor: 32);
    TestHarness.expectClose(highK.delta, lowK.delta * 2, 1e-9);
  });

  TestHarness.test('a non-positive kFactor is rejected', () {
    TestHarness.expectThrows<ArgumentError>(
      () => applyMatchResult(ratingA: 1200, ratingB: 1200, result: MatchResult.winA, kFactor: 0),
    );
    TestHarness.expectThrows<ArgumentError>(
      () => applyMatchResult(ratingA: 1200, ratingB: 1200, result: MatchResult.winA, kFactor: -5),
    );
  });

  TestHarness.test('ratings stay finite even for extreme gaps', () {
    final (updateA, updateB) =
        applyMatchResult(ratingA: 400, ratingB: 3000, result: MatchResult.winA);
    TestHarness.expectFinite(updateA.after);
    TestHarness.expectFinite(updateB.after);
  });
}
