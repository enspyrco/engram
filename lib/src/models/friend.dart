import 'package:meta/meta.dart';

import 'mastery_snapshot.dart';

@immutable
class Friend {
  const Friend({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.masterySnapshot,
    this.lastActiveAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      masterySnapshot:
          json['masterySnapshot'] != null
              ? MasterySnapshot.fromJson(
                json['masterySnapshot'] as Map<String, dynamic>,
              )
              : null,
      lastActiveAt: json['lastActiveAt'] as String?,
    );
  }

  final String uid;
  final String displayName;
  final String? photoUrl;
  final MasterySnapshot? masterySnapshot;
  final String? lastActiveAt;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'masterySnapshot': masterySnapshot?.toJson(),
    'lastActiveAt': lastActiveAt,
  };
}
