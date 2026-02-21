import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// Status of a single leg in a relay challenge.
enum RelayLegStatus { unclaimed, claimed, completed, stalled }

/// One leg of a relay challenge — a concept that must be mastered by a
/// single team member within 24 hours of claiming it.
@immutable
class RelayLeg {
  const RelayLeg({
    required this.conceptId,
    required this.conceptName,
    this.claimedByUid,
    this.claimedByName,
    this.claimedAt,
    this.completedAt,
    this.lastStallNudgeAt,
  });

  factory RelayLeg.fromJson(Map<String, dynamic> json) {
    return RelayLeg(
      conceptId: json['conceptId'] as String,
      conceptName: json['conceptName'] as String,
      claimedByUid: json['claimedByUid'] as String?,
      claimedByName: json['claimedByName'] as String?,
      claimedAt:
          json['claimedAt'] != null
              ? DateTime.parse(json['claimedAt'] as String)
              : null,
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'] as String)
              : null,
      lastStallNudgeAt:
          json['lastStallNudgeAt'] != null
              ? DateTime.parse(json['lastStallNudgeAt'] as String)
              : null,
    );
  }

  final String conceptId;
  final String conceptName;
  final String? claimedByUid;
  final String? claimedByName;
  final DateTime? claimedAt;
  final DateTime? completedAt;

  /// Last time a stall nudge was sent for this leg (6h debounce).
  final DateTime? lastStallNudgeAt;

  /// Computed status based on field state at the given time.
  ///
  /// Pure — depends only on the leg's fields and the supplied [now].
  RelayLegStatus statusAt(DateTime now) {
    if (completedAt != null) return RelayLegStatus.completed;
    if (claimedAt != null) {
      return isOverdueAt(now) ? RelayLegStatus.stalled : RelayLegStatus.claimed;
    }
    return RelayLegStatus.unclaimed;
  }

  /// Deadline is 24 hours after claiming.
  DateTime? get deadline {
    if (claimedAt == null) return null;
    return claimedAt!.add(const Duration(hours: 24));
  }

  /// Whether the claim window has expired without completion at [now].
  bool isOverdueAt(DateTime now) {
    if (claimedAt == null || completedAt != null) return false;
    return now.isAfter(deadline!);
  }

  RelayLeg withClaimed({
    required String uid,
    required String displayName,
    required DateTime timestamp,
  }) {
    return RelayLeg(
      conceptId: conceptId,
      conceptName: conceptName,
      claimedByUid: uid,
      claimedByName: displayName,
      claimedAt: timestamp,
      completedAt: completedAt,
      lastStallNudgeAt: lastStallNudgeAt,
    );
  }

  RelayLeg withCompleted(DateTime timestamp) {
    return RelayLeg(
      conceptId: conceptId,
      conceptName: conceptName,
      claimedByUid: claimedByUid,
      claimedByName: claimedByName,
      claimedAt: claimedAt,
      completedAt: timestamp,
      lastStallNudgeAt: lastStallNudgeAt,
    );
  }

  RelayLeg withStallNudgeAt(DateTime timestamp) {
    return RelayLeg(
      conceptId: conceptId,
      conceptName: conceptName,
      claimedByUid: claimedByUid,
      claimedByName: claimedByName,
      claimedAt: claimedAt,
      completedAt: completedAt,
      lastStallNudgeAt: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'conceptId': conceptId,
    'conceptName': conceptName,
    'claimedByUid': claimedByUid,
    'claimedByName': claimedByName,
    'claimedAt': claimedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'lastStallNudgeAt': lastStallNudgeAt?.toIso8601String(),
  };
}

/// A cooperative relay challenge — a chain of concepts that must be mastered
/// sequentially by different team members, each within a 24-hour window.
@immutable
class RelayChallenge {
  RelayChallenge({
    required this.id,
    required this.title,
    List<RelayLeg> legs = const [],
    required this.createdAt,
    required this.createdByUid,
    this.completedAt,
  }) : legs = IList(legs);

  const RelayChallenge._raw({
    required this.id,
    required this.title,
    required this.legs,
    required this.createdAt,
    required this.createdByUid,
    this.completedAt,
  });

  factory RelayChallenge.fromJson(Map<String, dynamic> json) {
    return RelayChallenge._raw(
      id: json['id'] as String,
      title: json['title'] as String,
      legs:
          (json['legs'] as List<dynamic>?)
              ?.map((e) => RelayLeg.fromJson(e as Map<String, dynamic>))
              .toIList() ??
          const IListConst([]),
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdByUid: json['createdByUid'] as String,
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'] as String)
              : null,
    );
  }

  final String id;
  final String title;
  final IList<RelayLeg> legs;
  final DateTime createdAt;
  final String createdByUid;
  final DateTime? completedAt;

  /// Whether every leg has been completed.
  bool get isComplete => completedAt != null;

  /// Number of completed legs.
  int get completedLegs => legs.where((l) => l.completedAt != null).length;

  /// Index of the first uncompleted leg, or legs.length if all done.
  int get currentLegIndex {
    for (var i = 0; i < legs.length; i++) {
      if (legs[i].completedAt == null) return i;
    }
    return legs.length;
  }

  /// Progress fraction (0.0 – 1.0).
  double get progress {
    if (legs.isEmpty) return 1.0;
    return completedLegs / legs.length;
  }

  /// Whether any leg is stalled (overdue) at the given time.
  bool hasStallAt(DateTime now) =>
      legs.any((l) => l.statusAt(now) == RelayLegStatus.stalled);

  RelayChallenge withLegClaimed(
    int legIndex, {
    required String uid,
    required String displayName,
    required DateTime timestamp,
  }) {
    final updatedLegs = legs.replace(
      legIndex,
      legs[legIndex].withClaimed(
        uid: uid,
        displayName: displayName,
        timestamp: timestamp,
      ),
    );
    return RelayChallenge._raw(
      id: id,
      title: title,
      legs: updatedLegs,
      createdAt: createdAt,
      createdByUid: createdByUid,
      completedAt: completedAt,
    );
  }

  RelayChallenge withLegCompleted(int legIndex, DateTime timestamp) {
    final updatedLegs = legs.replace(
      legIndex,
      legs[legIndex].withCompleted(timestamp),
    );
    return RelayChallenge._raw(
      id: id,
      title: title,
      legs: updatedLegs,
      createdAt: createdAt,
      createdByUid: createdByUid,
      completedAt: completedAt,
    );
  }

  RelayChallenge withCompleted(DateTime timestamp) => RelayChallenge._raw(
    id: id,
    title: title,
    legs: legs,
    createdAt: createdAt,
    createdByUid: createdByUid,
    completedAt: timestamp,
  );

  RelayChallenge withLegStallNudge(int legIndex, DateTime timestamp) {
    final updatedLegs = legs.replace(
      legIndex,
      legs[legIndex].withStallNudgeAt(timestamp),
    );
    return RelayChallenge._raw(
      id: id,
      title: title,
      legs: updatedLegs,
      createdAt: createdAt,
      createdByUid: createdByUid,
      completedAt: completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'legs': legs.map((l) => l.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'createdByUid': createdByUid,
    'completedAt': completedAt?.toIso8601String(),
  };
}
