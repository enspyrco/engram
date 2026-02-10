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
      lastSessionAt: json['lastSessionAt'] as String?,
      currentStreak: json['currentStreak'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
    );
  }

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? wikiUrl;
  final String? lastSessionAt;
  final int currentStreak;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'wikiUrl': wikiUrl,
        'lastSessionAt': lastSessionAt,
        'currentStreak': currentStreak,
        'createdAt': createdAt,
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
    required String timestamp,
    required int streak,
  }) =>
      UserProfile(
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
