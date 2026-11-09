import 'dart:convert';
import 'dart:io';

import 'elo_calculator.dart';
import 'models.dart';

/// Head-to-head tally between two players, always from the perspective
/// of whichever name was passed first to [EloTracker.headToHead].
class HeadToHead {
  final int wins;
  final int losses;
  final int draws;

  const HeadToHead(this.wins, this.losses, this.draws);

  int get totalMatches => wins + losses + draws;
}

class UnknownPlayerException implements Exception {
  final String name;
  const UnknownPlayerException(this.name);

  @override
  String toString() => 'No player named "$name" is registered.';
}

class DuplicatePlayerException implements Exception {
  final String name;
  const DuplicatePlayerException(this.name);

  @override
  String toString() => 'A player named "$name" is already registered.';
}

/// Tracks a pool of players' Elo ratings over a sequence of matches.
/// This is the stateful heart of the project: [EloCalculator]'s functions
/// are pure, but a real tracker needs a player registry, a shared match
/// counter (so every player's history can be lined up against the same
/// timeline), and a match log for head-to-head lookups -- all of which
/// live here.
class EloTracker {
  final Map<String, Player> _players = {};
  final List<MatchRecord> _matchLog = [];
  int _matchCount = 0;

  static const double defaultInitialRating = 1200;
  static const double defaultKFactor = 32;

  /// Registers a new player. Throws [DuplicatePlayerException] if a
  /// player with that name already exists -- ratings are meaningless
  /// without a stable identity behind them, so silently overwriting an
  /// existing player's history would be a real bug, not a convenience.
  Player addPlayer(String name, {double initialRating = defaultInitialRating}) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    if (_players.containsKey(name)) {
      throw DuplicatePlayerException(name);
    }
    final player = Player(name, initialRating);
    _players[name] = player;
    return player;
  }

  Player? player(String name) => _players[name];

  List<Player> get allPlayers => _players.values.toList(growable: false);

  Player _requirePlayer(String name) {
    final p = _players[name];
    if (p == null) {
      throw UnknownPlayerException(name);
    }
    return p;
  }

  /// Records a match between two *different*, already-registered players
  /// and updates both ratings. Returns the completed [MatchRecord].
  MatchRecord recordMatch(
    String nameA,
    String nameB,
    MatchResult result, {
    double kFactor = defaultKFactor,
  }) {
    if (nameA == nameB) {
      throw ArgumentError('A player cannot play a match against themselves ("$nameA").');
    }
    final playerA = _requirePlayer(nameA);
    final playerB = _requirePlayer(nameB);

    final (updateA, updateB) = applyMatchResult(
      ratingA: playerA.rating,
      ratingB: playerB.rating,
      result: result,
      kFactor: kFactor,
    );

    final index = _matchCount;
    playerA.recordRating(index, updateA.after);
    playerB.recordRating(index, updateB.after);
    _matchCount++;

    final record = MatchRecord(
      matchIndex: index,
      playerA: nameA,
      playerB: nameB,
      result: result,
      updateA: updateA,
      updateB: updateB,
    );
    _matchLog.add(record);
    return record;
  }

  /// All players ranked by current rating, highest first. Ties are
  /// broken by name so the ordering is deterministic (and therefore
  /// testable) rather than depending on map iteration order.
  List<Player> leaderboard() {
    final players = allPlayers;
    players.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      return byRating != 0 ? byRating : a.name.compareTo(b.name);
    });
    return players;
  }

  List<RatingPoint> history(String name) => _requirePlayer(name).history;

  /// Head-to-head record between [nameA] and [nameB], from [nameA]'s
  /// perspective (a win for nameA counts toward `wins`).
  HeadToHead headToHead(String nameA, String nameB) {
    _requirePlayer(nameA);
    _requirePlayer(nameB);

    int wins = 0, losses = 0, draws = 0;
    for (final m in _matchLog) {
      final isAvsB = m.playerA == nameA && m.playerB == nameB;
      final isBvsA = m.playerA == nameB && m.playerB == nameA;
      if (!isAvsB && !isBvsA) continue;

      final effectiveResult = isAvsB
          ? m.result
          : switch (m.result) {
              MatchResult.winA => MatchResult.winB,
              MatchResult.winB => MatchResult.winA,
              MatchResult.draw => MatchResult.draw,
            };

      switch (effectiveResult) {
        case MatchResult.winA:
          wins++;
        case MatchResult.winB:
          losses++;
        case MatchResult.draw:
          draws++;
      }
    }
    return HeadToHead(wins, losses, draws);
  }

  List<MatchRecord> get matchLog => List.unmodifiable(_matchLog);

  Map<String, dynamic> toJson() => {
        'matchCount': _matchCount,
        'players': _players.values.map((p) => p.toJson()).toList(),
        'matchLog': _matchLog.map((m) => m.toJson()).toList(),
      };

  static EloTracker fromJson(Map<String, dynamic> json) {
    final tracker = EloTracker();
    for (final playerJson in (json['players'] as List<dynamic>)) {
      final player = Player.fromJson(playerJson as Map<String, dynamic>);
      tracker._players[player.name] = player;
    }
    for (final matchJson in (json['matchLog'] as List<dynamic>)) {
      tracker._matchLog.add(MatchRecord.fromJson(matchJson as Map<String, dynamic>));
    }
    tracker._matchCount = json['matchCount'] as int;
    return tracker;
  }

  void saveToFile(String path) {
    File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
  }

  static EloTracker loadFromFile(String path) {
    final content = File(path).readAsStringSync();
    return EloTracker.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
