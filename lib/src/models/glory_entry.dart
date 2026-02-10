import 'package:meta/meta.dart';

/// A leaderboard entry for the glory board.
///
/// Points accumulate from three sources: guardian duty (keeping clusters
/// healthy), repair mission completions, and team goal contributions.
@immutable
class GloryEntry {
  const GloryEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.guardianPoints = 0,
    this.missionPoints = 0,
    this.goalPoints = 0,
  });

  factory GloryEntry.fromJson(Map<String, dynamic> json) {
    return GloryEntry(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      guardianPoints: json['guardianPoints'] as int? ?? 0,
      missionPoints: json['missionPoints'] as int? ?? 0,
      goalPoints: json['goalPoints'] as int? ?? 0,
    );
  }

  final String uid;
  final String displayName;
  final String? photoUrl;

  /// Points earned from keeping guarded clusters above 80% health.
  final int guardianPoints;

  /// Points earned from completing repair mission reviews.
  final int missionPoints;

  /// Points earned from contributing to team goals.
  final int goalPoints;

  /// Sum of all point categories.
  int get totalPoints => guardianPoints + missionPoints + goalPoints;

  GloryEntry withGuardianPoints(int points) => GloryEntry(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        guardianPoints: points,
        missionPoints: missionPoints,
        goalPoints: goalPoints,
      );

  GloryEntry withMissionPoints(int points) => GloryEntry(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        guardianPoints: guardianPoints,
        missionPoints: points,
        goalPoints: goalPoints,
      );

  GloryEntry withGoalPoints(int points) => GloryEntry(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        guardianPoints: guardianPoints,
        missionPoints: missionPoints,
        goalPoints: points,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'guardianPoints': guardianPoints,
        'missionPoints': missionPoints,
        'goalPoints': goalPoints,
      };
}
