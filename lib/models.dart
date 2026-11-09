import 'elo_calculator.dart';

/// One point in a player's rating history: the rating they held right
/// after the match at [matchIndex] (the tracker's global, 0-based match
/// counter at the time -- shared across all players, so two players'
/// histories can be cross-referenced by index).
class RatingPoint {
  final int matchIndex;
  final double rating;

  const RatingPoint(this.matchIndex, this.rating);

  Map<String, dynamic> toJson() => {'matchIndex': matchIndex, 'rating': rating};

  factory RatingPoint.fromJson(Map<String, dynamic> json) =>
      RatingPoint(json['matchIndex'] as int, (json['rating'] as num).toDouble());

  @override
  String toString() => '#$matchIndex: ${rating.toStringAsFixed(1)}';
}

/// A registered player: current rating plus the full history of how it
/// got there. [history] always starts with the player's initial rating
/// at matchIndex -1 (before any match), so "rating at signup" and "rating
/// after match 0" are always two distinct, unambiguous points.
class Player {
  final String name;
  double rating;
  final List<RatingPoint> history;

  Player(this.name, double initialRating)
      : rating = initialRating,
        history = [RatingPoint(-1, initialRating)];

  void recordRating(int matchIndex, double newRating) {
    rating = newRating;
    history.add(RatingPoint(matchIndex, newRating));
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'rating': rating,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final historyJson = json['history'] as List<dynamic>;
    final history = historyJson
        .map((h) => RatingPoint.fromJson(h as Map<String, dynamic>))
        .toList();
    final player = Player(json['name'] as String, history.first.rating);
    // Replace the auto-created single-point history with the full,
    // restored one (including every intermediate match), then set the
    // live rating to match its last point.
    history.removeAt(0); // Player's constructor already added point -1
    for (final point in history) {
      player.history.add(point);
    }
    player.rating = (json['rating'] as num).toDouble();
    return player;
  }

  @override
  String toString() => '$name (${rating.toStringAsFixed(1)})';
}

/// A record of one completed match, kept for H2H lookups and an audit
/// trail -- includes both players' before/after ratings so a match log
/// is self-contained and doesn't need the live Player objects to explain
/// what happened.
class MatchRecord {
  final int matchIndex;
  final String playerA;
  final String playerB;
  final MatchResult result;
  final RatingUpdate updateA;
  final RatingUpdate updateB;

  const MatchRecord({
    required this.matchIndex,
    required this.playerA,
    required this.playerB,
    required this.result,
    required this.updateA,
    required this.updateB,
  });

  Map<String, dynamic> toJson() => {
        'matchIndex': matchIndex,
        'playerA': playerA,
        'playerB': playerB,
        'result': result.name,
        'ratingABefore': updateA.before,
        'ratingAAfter': updateA.after,
        'ratingBBefore': updateB.before,
        'ratingBAfter': updateB.after,
      };

  factory MatchRecord.fromJson(Map<String, dynamic> json) => MatchRecord(
        matchIndex: json['matchIndex'] as int,
        playerA: json['playerA'] as String,
        playerB: json['playerB'] as String,
        result: MatchResult.values.byName(json['result'] as String),
        updateA: RatingUpdate(
          (json['ratingABefore'] as num).toDouble(),
          (json['ratingAAfter'] as num).toDouble(),
        ),
        updateB: RatingUpdate(
          (json['ratingBBefore'] as num).toDouble(),
          (json['ratingBAfter'] as num).toDouble(),
        ),
      );
}
