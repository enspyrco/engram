import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// Lifecycle status of an entropy storm.
enum StormStatus { scheduled, active, survived, failed }

/// An opt-in entropy storm event — 48 hours of 2x freshness decay.
///
/// Players voluntarily opt in before the storm starts. During the storm,
/// all freshness calculations use a 2x decay multiplier, making the network
/// health drop faster and potentially triggering catastrophe tiers. If the
/// team keeps health above [healthThreshold] for the duration, all
/// participants earn storm glory points.
@immutable
class EntropyStorm {
  EntropyStorm({
    required this.id,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.healthThreshold = 0.7,
    required this.status,
    this.lowestHealth,
    List<String> participantUids = const [],
    required this.createdByUid,
  }) : participantUids = IList(participantUids);

  const EntropyStorm._raw({
    required this.id,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.healthThreshold = 0.7,
    required this.status,
    this.lowestHealth,
    required this.participantUids,
    required this.createdByUid,
  });

  factory EntropyStorm.fromJson(Map<String, dynamic> json) {
    return EntropyStorm._raw(
      id: json['id'] as String,
      scheduledStart: json['scheduledStart'] as String,
      scheduledEnd: json['scheduledEnd'] as String,
      healthThreshold: (json['healthThreshold'] as num?)?.toDouble() ?? 0.7,
      status: StormStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => StormStatus.scheduled,
      ),
      lowestHealth: (json['lowestHealth'] as num?)?.toDouble(),
      participantUids: (json['participantUids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toIList() ??
          const IListConst([]),
      createdByUid: json['createdByUid'] as String,
    );
  }

  final String id;
  final String scheduledStart;
  final String scheduledEnd;
  final double healthThreshold;
  final StormStatus status;

  /// Lowest network health observed during the storm.
  final double? lowestHealth;

  /// UIDs of players who opted in before the storm started.
  final IList<String> participantUids;

  final String createdByUid;

  /// Whether the storm is currently active (between start and end).
  bool get isActive => status == StormStatus.active;

  /// Check if the storm should be active at a given time.
  bool isActiveAt(DateTime now) {
    if (status != StormStatus.active && status != StormStatus.scheduled) {
      return false;
    }
    final start = DateTime.parse(scheduledStart);
    final end = DateTime.parse(scheduledEnd);
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Remaining duration of the storm (null if not active).
  Duration? remainingDuration({DateTime? now}) {
    final currentTime = now ?? DateTime.now().toUtc();
    final end = DateTime.parse(scheduledEnd);
    if (currentTime.isAfter(end)) return Duration.zero;
    return end.difference(currentTime);
  }

  /// Duration until the storm starts (null if already started).
  Duration? timeUntilStart({DateTime? now}) {
    final currentTime = now ?? DateTime.now().toUtc();
    final start = DateTime.parse(scheduledStart);
    if (currentTime.isAfter(start)) return Duration.zero;
    return start.difference(currentTime);
  }

  EntropyStorm withParticipant(String uid) {
    if (participantUids.contains(uid)) return this;
    return EntropyStorm._raw(
      id: id,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      healthThreshold: healthThreshold,
      status: status,
      lowestHealth: lowestHealth,
      participantUids: participantUids.add(uid),
      createdByUid: createdByUid,
    );
  }

  EntropyStorm withoutParticipant(String uid) {
    return EntropyStorm._raw(
      id: id,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      healthThreshold: healthThreshold,
      status: status,
      lowestHealth: lowestHealth,
      participantUids: participantUids.remove(uid),
      createdByUid: createdByUid,
    );
  }

  EntropyStorm withStatus(StormStatus newStatus) => EntropyStorm._raw(
        id: id,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        healthThreshold: healthThreshold,
        status: newStatus,
        lowestHealth: lowestHealth,
        participantUids: participantUids,
        createdByUid: createdByUid,
      );

  EntropyStorm withLowestHealth(double health) => EntropyStorm._raw(
        id: id,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        healthThreshold: healthThreshold,
        status: status,
        lowestHealth: health,
        participantUids: participantUids,
        createdByUid: createdByUid,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduledStart': scheduledStart,
        'scheduledEnd': scheduledEnd,
        'healthThreshold': healthThreshold,
        'status': status.name,
        'lowestHealth': lowestHealth,
        'participantUids': participantUids.toList(),
        'createdByUid': createdByUid,
      };
}
