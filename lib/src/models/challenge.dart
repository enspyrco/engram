import 'package:meta/meta.dart';

enum ChallengeStatus { pending, accepted, completed, declined }

@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.quizItemSnapshot,
    required this.conceptName,
    required this.createdAt,
    this.status = ChallengeStatus.pending,
    this.score,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      fromUid: json['fromUid'] as String,
      fromName: json['fromName'] as String,
      toUid: json['toUid'] as String,
      quizItemSnapshot: Map<String, dynamic>.from(
        json['quizItemSnapshot'] as Map,
      ),
      conceptName: json['conceptName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: ChallengeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      score: json['score'] as int?,
    );
  }

  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final Map<String, dynamic> quizItemSnapshot;
  final String conceptName;
  final DateTime createdAt;
  final ChallengeStatus status;
  final int? score;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUid': fromUid,
    'fromName': fromName,
    'toUid': toUid,
    'quizItemSnapshot': quizItemSnapshot,
    'conceptName': conceptName,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'score': score,
  };

  Challenge withStatus(ChallengeStatus newStatus, {int? score}) => Challenge(
    id: id,
    fromUid: fromUid,
    fromName: fromName,
    toUid: toUid,
    quizItemSnapshot: quizItemSnapshot,
    conceptName: conceptName,
    createdAt: createdAt,
    status: newStatus,
    score: score ?? this.score,
  );
}
