import 'dart:io';

import 'package:esports_elo_tracker/elo_calculator.dart';
import 'package:esports_elo_tracker/elo_tracker.dart';

import 'test_harness.dart';

void registerEloTrackerTests() {
  TestHarness.test('addPlayer registers with the default rating', () {
    final tracker = EloTracker();
    final p = tracker.addPlayer('Nimzer');
    TestHarness.expectEqual(p.rating, EloTracker.defaultInitialRating);
    TestHarness.expectEqual(tracker.player('Nimzer')?.name, 'Nimzer');
  });

  TestHarness.test('addPlayer rejects a duplicate name', () {
    final tracker = EloTracker()..addPlayer('Nimzer');
    TestHarness.expectThrows<DuplicatePlayerException>(() => tracker.addPlayer('Nimzer'));
  });

  TestHarness.test('addPlayer rejects a blank name', () {
    final tracker = EloTracker();
    TestHarness.expectThrows<ArgumentError>(() => tracker.addPlayer('   '));
  });

  TestHarness.test('recordMatch against an unregistered player throws', () {
    final tracker = EloTracker()..addPlayer('Nimzer');
    TestHarness.expectThrows<UnknownPlayerException>(
      () => tracker.recordMatch('Nimzer', 'Ghost', MatchResult.winA),
    );
  });

  TestHarness.test('a player cannot play a match against themselves', () {
    final tracker = EloTracker()..addPlayer('Nimzer');
    TestHarness.expectThrows<ArgumentError>(
      () => tracker.recordMatch('Nimzer', 'Nimzer', MatchResult.draw),
    );
  });

  TestHarness.test('recordMatch updates both players\' live ratings', () {
    final tracker = EloTracker()
      ..addPlayer('A', initialRating: 1200)
      ..addPlayer('B', initialRating: 1200);
    tracker.recordMatch('A', 'B', MatchResult.winA);
    TestHarness.expectEqual(tracker.player('A')!.rating, 1216.0);
    TestHarness.expectEqual(tracker.player('B')!.rating, 1184.0);
  });

  TestHarness.test('leaderboard is sorted by rating, highest first', () {
    final tracker = EloTracker()
      ..addPlayer('Low', initialRating: 1000)
      ..addPlayer('High', initialRating: 1800)
      ..addPlayer('Mid', initialRating: 1400);
    final board = tracker.leaderboard();
    TestHarness.expectListEqual(board.map((p) => p.name).toList(), ['High', 'Mid', 'Low']);
  });

  TestHarness.test('leaderboard breaks exact ties by name, for a deterministic order', () {
    final tracker = EloTracker()
      ..addPlayer('Zed', initialRating: 1500)
      ..addPlayer('Alpha', initialRating: 1500);
    final board = tracker.leaderboard();
    TestHarness.expectListEqual(board.map((p) => p.name).toList(), ['Alpha', 'Zed']);
  });

  TestHarness.test('history starts at matchIndex -1 with the initial rating', () {
    final tracker = EloTracker()..addPlayer('A', initialRating: 1337);
    final h = tracker.history('A');
    TestHarness.expectEqual(h.length, 1);
    TestHarness.expectEqual(h.first.matchIndex, -1);
    TestHarness.expectEqual(h.first.rating, 1337.0);
  });

  TestHarness.test('history grows by one point per match the player is in', () {
    final tracker = EloTracker()
      ..addPlayer('A')
      ..addPlayer('B')
      ..addPlayer('C');
    tracker.recordMatch('A', 'B', MatchResult.winA); // involves A, B
    tracker.recordMatch('A', 'C', MatchResult.winB); // involves A, C
    tracker.recordMatch('B', 'C', MatchResult.draw); // involves B, C
    // Each player is in exactly 2 of the 3 matches above, so every
    // history should be the initial point plus 2 more.
    TestHarness.expectEqual(tracker.history('A').length, 3);
    TestHarness.expectEqual(tracker.history('B').length, 3);
    TestHarness.expectEqual(tracker.history('C').length, 3);
  });

  TestHarness.test('the shared match index increments once per match, across all players', () {
    final tracker = EloTracker()
      ..addPlayer('A')
      ..addPlayer('B')
      ..addPlayer('C');
    tracker.recordMatch('A', 'B', MatchResult.winA);
    final secondRecord = tracker.recordMatch('B', 'C', MatchResult.winB);
    TestHarness.expectEqual(secondRecord.matchIndex, 1);
  });

  TestHarness.test('headToHead counts wins/losses/draws from the first name\'s perspective', () {
    final tracker = EloTracker()
      ..addPlayer('A')
      ..addPlayer('B');
    tracker.recordMatch('A', 'B', MatchResult.winA); // A beats B
    tracker.recordMatch('B', 'A', MatchResult.winA); // B beats A (A is "B" arg here)
    tracker.recordMatch('A', 'B', MatchResult.draw);

    final ab = tracker.headToHead('A', 'B');
    TestHarness.expectEqual(ab.wins, 1);
    TestHarness.expectEqual(ab.losses, 1);
    TestHarness.expectEqual(ab.draws, 1);

    // Reversed query must mirror wins/losses, not repeat them.
    final ba = tracker.headToHead('B', 'A');
    TestHarness.expectEqual(ba.wins, 1);
    TestHarness.expectEqual(ba.losses, 1);
    TestHarness.expectEqual(ba.draws, 1);
  });

  TestHarness.test('headToHead ignores matches that don\'t involve both named players', () {
    final tracker = EloTracker()
      ..addPlayer('A')
      ..addPlayer('B')
      ..addPlayer('C');
    tracker.recordMatch('A', 'C', MatchResult.winA);
    tracker.recordMatch('B', 'C', MatchResult.winB);
    final ab = tracker.headToHead('A', 'B');
    TestHarness.expectEqual(ab.totalMatches, 0);
  });

  TestHarness.test('toJson/fromJson round-trips ratings, history, and the match log exactly', () {
    final original = EloTracker()
      ..addPlayer('A', initialRating: 1500)
      ..addPlayer('B', initialRating: 1300);
    original.recordMatch('A', 'B', MatchResult.winA);
    original.recordMatch('A', 'B', MatchResult.winB);

    final restored = EloTracker.fromJson(original.toJson());

    TestHarness.expectEqual(restored.player('A')!.rating, original.player('A')!.rating);
    TestHarness.expectEqual(restored.player('B')!.rating, original.player('B')!.rating);
    TestHarness.expectEqual(restored.history('A').length, original.history('A').length);
    TestHarness.expectEqual(restored.matchLog.length, original.matchLog.length);
    final h2hOriginal = original.headToHead('A', 'B');
    final h2hRestored = restored.headToHead('A', 'B');
    TestHarness.expectEqual(h2hRestored.wins, h2hOriginal.wins);
    TestHarness.expectEqual(h2hRestored.losses, h2hOriginal.losses);
  });

  TestHarness.test('saveToFile/loadFromFile round-trips through real JSON on disk', () {
    final tracker = EloTracker()
      ..addPlayer('A', initialRating: 1600)
      ..addPlayer('B', initialRating: 1400);
    tracker.recordMatch('A', 'B', MatchResult.winB);

    final tempPath =
        '${Directory.systemTemp.path}/elo_tracker_test_${DateTime.now().microsecondsSinceEpoch}.json';
    try {
      tracker.saveToFile(tempPath);
      TestHarness.expectTrue(File(tempPath).existsSync());

      final loaded = EloTracker.loadFromFile(tempPath);
      TestHarness.expectEqual(loaded.player('A')!.rating, tracker.player('A')!.rating);
      TestHarness.expectEqual(loaded.player('B')!.rating, tracker.player('B')!.rating);
      TestHarness.expectEqual(loaded.matchLog.length, 1);
    } finally {
      final f = File(tempPath);
      if (f.existsSync()) f.deleteSync();
    }
  });
}
