import 'package:meta/meta.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.wikiUrl,
    this.lastSessionAt,
    required this.currentStreak,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      wikiUrl: json['wikiUrl'] as String?,
      lastSessionAt:
          json['lastSessionAt'] != null
              ? DateTime.parse(json['lastSessionAt'] as String)
              : null,
      currentStreak: json['currentStreak'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? wikiUrl;
  final DateTime? lastSessionAt;
  final int currentStreak;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'wikiUrl': wikiUrl,
    'lastSessionAt': lastSessionAt?.toIso8601String(),
    'currentStreak': currentStreak,
    'createdAt': createdAt.toIso8601String(),
  };

  UserProfile withWikiUrl(String url) => UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    photoUrl: photoUrl,
    wikiUrl: url,
    lastSessionAt: lastSessionAt,
    currentStreak: currentStreak,
    createdAt: createdAt,
  );

  UserProfile withLastSession({
    required DateTime timestamp,
    required int streak,
  }) => UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    photoUrl: photoUrl,
    wikiUrl: wikiUrl,
    lastSessionAt: timestamp,
    currentStreak: streak,
    createdAt: createdAt,
  );
}
