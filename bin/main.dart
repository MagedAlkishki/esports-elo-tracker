import 'dart:io';

import 'package:esports_elo_tracker/elo_calculator.dart';
import 'package:esports_elo_tracker/elo_tracker.dart';

void main(List<String> args) {
  var tracker = EloTracker();
  print('esports-elo-tracker -- type HELP for commands.');

  while (true) {
    stdout.write('> ');
    final line = stdin.readLineSync();
    if (line == null) break;

    final parts = line.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) continue;

    final command = parts[0].toUpperCase();
    try {
      switch (command) {
        case 'ADD':
          _handleAdd(tracker, parts);
        case 'MATCH':
          _handleMatch(tracker, parts);
        case 'LEADERBOARD':
          _handleLeaderboard(tracker);
        case 'HISTORY':
          _handleHistory(tracker, parts);
        case 'H2H':
          _handleHeadToHead(tracker, parts);
        case 'SAVE':
          _handleSave(tracker, parts);
        case 'LOAD':
          // LOAD replaces the whole tracker, so it's handled here rather
          // than in a helper -- a helper can't reassign main()'s local.
          if (parts.length < 2) {
            print('Usage: LOAD <file>');
          } else {
            tracker = EloTracker.loadFromFile(parts[1]);
            print('Loaded ${tracker.allPlayers.length} players from ${parts[1]}');
          }
        case 'HELP':
          _printHelp();
        case 'EXIT':
        case 'QUIT':
          return;
        default:
          print('Unknown command. Type HELP.');
      }
    } on FormatException catch (e) {
      print('Error: ${e.message}');
    } catch (e) {
      print('Error: $e');
    }
  }
}

void _handleAdd(EloTracker tracker, List<String> parts) {
  if (parts.length < 2) {
    print('Usage: ADD <name> [initial_rating]');
    return;
  }
  final name = parts[1];
  final rating = parts.length > 2
      ? double.parse(parts[2])
      : EloTracker.defaultInitialRating;
  final player = tracker.addPlayer(name, initialRating: rating);
  print('Registered $player');
}

void _handleMatch(EloTracker tracker, List<String> parts) {
  if (parts.length < 4) {
    print('Usage: MATCH <playerA> <playerB> A|B|DRAW [kFactor]');
    return;
  }
  final nameA = parts[1];
  final nameB = parts[2];
  final resultText = parts[3].toUpperCase();
  final result = switch (resultText) {
    'A' => MatchResult.winA,
    'B' => MatchResult.winB,
    'DRAW' => MatchResult.draw,
    _ => throw FormatException('result must be A, B, or DRAW (got "$resultText")'),
  };
  final kFactor =
      parts.length > 4 ? double.parse(parts[4]) : EloTracker.defaultKFactor;

  final record = tracker.recordMatch(nameA, nameB, result, kFactor: kFactor);
  print('$nameA: ${record.updateA}');
  print('$nameB: ${record.updateB}');
}

void _handleLeaderboard(EloTracker tracker) {
  final board = tracker.leaderboard();
  if (board.isEmpty) {
    print('No players registered yet.');
    return;
  }
  for (var i = 0; i < board.length; i++) {
    final p = board[i];
    print('  ${i + 1}. ${p.name.padRight(20)} ${p.rating.toStringAsFixed(1)}');
  }
}

void _handleHistory(EloTracker tracker, List<String> parts) {
  if (parts.length < 2) {
    print('Usage: HISTORY <name>');
    return;
  }
  for (final point in tracker.history(parts[1])) {
    print('  $point');
  }
}

void _handleHeadToHead(EloTracker tracker, List<String> parts) {
  if (parts.length < 3) {
    print('Usage: H2H <playerA> <playerB>');
    return;
  }
  final h2h = tracker.headToHead(parts[1], parts[2]);
  print('${parts[1]} vs ${parts[2]}: ${h2h.wins}W-${h2h.losses}L-${h2h.draws}D '
      '(${h2h.totalMatches} matches)');
}

void _handleSave(EloTracker tracker, List<String> parts) {
  if (parts.length < 2) {
    print('Usage: SAVE <file>');
    return;
  }
  tracker.saveToFile(parts[1]);
  print('Saved to ${parts[1]}');
}

void _printHelp() {
  print('''
Commands:
  ADD <name> [rating]              register a player (default rating 1200)
  MATCH <A> <B> A|B|DRAW [k]       record a match result (default k=32)
  LEADERBOARD                      show all players ranked by rating
  HISTORY <name>                   show a player's rating over time
  H2H <A> <B>                      head-to-head record between two players
  SAVE <file>                      save all state to a JSON file
  LOAD <file>                      load state from a JSON file (replaces everything)
  HELP                             this message
  EXIT                             quit''');
}
