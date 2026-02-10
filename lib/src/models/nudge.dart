import 'package:meta/meta.dart';

enum NudgeStatus { pending, seen }

@immutable
class Nudge {
  const Nudge({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.conceptName,
    this.message,
    required this.createdAt,
    this.status = NudgeStatus.pending,
  });

  factory Nudge.fromJson(Map<String, dynamic> json) {
    return Nudge(
      id: json['id'] as String,
      fromUid: json['fromUid'] as String,
      fromName: json['fromName'] as String,
      toUid: json['toUid'] as String,
      conceptName: json['conceptName'] as String,
      message: json['message'] as String?,
      createdAt: json['createdAt'] as String,
      status: NudgeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => NudgeStatus.pending,
      ),
    );
  }

  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String conceptName;
  final String? message;
  final String createdAt;
  final NudgeStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'conceptName': conceptName,
        'message': message,
        'createdAt': createdAt,
        'status': status.name,
      };

  Nudge withStatus(NudgeStatus newStatus) => Nudge(
        id: id,
        fromUid: fromUid,
        fromName: fromName,
        toUid: toUid,
        conceptName: conceptName,
        message: message,
        createdAt: createdAt,
        status: newStatus,
      );
}
