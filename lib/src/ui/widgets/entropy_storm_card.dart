import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/entropy_storm.dart';

/// A card displaying the current entropy storm state.
///
/// Shows different layouts based on storm status:
/// - **Scheduled**: countdown to start, opt-in/out buttons, participant count
/// - **Active**: countdown to end, live health threshold indicator
/// - **Survived**: celebration with points earned
/// - **Failed**: result display
class EntropyStormCard extends StatelessWidget {
  const EntropyStormCard({
    required this.storm,
    required this.currentUid,
    this.onOptIn,
    this.onOptOut,
    super.key,
  });

  final EntropyStorm storm;
  final String? currentUid;
  final VoidCallback? onOptIn;
  final VoidCallback? onOptOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Color? _cardColor(BuildContext context) {
    return switch (storm.status) {
      StormStatus.active => Colors.deepPurple.withValues(alpha: 0.08),
      StormStatus.survived => Colors.green.withValues(alpha: 0.08),
      StormStatus.failed => Colors.red.withValues(alpha: 0.08),
      StormStatus.scheduled => null,
    };
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label) = switch (storm.status) {
      StormStatus.scheduled => (Icons.schedule, 'Storm Incoming'),
      StormStatus.active => (Icons.thunderstorm, 'Storm Active!'),
      StormStatus.survived => (Icons.celebration, 'Storm Survived!'),
      StormStatus.failed => (Icons.cloud_off, 'Storm Failed'),
    };

    return Row(
      children: [
        Icon(icon, size: 18, color: _statusColor()),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(color: _statusColor()),
        ),
        const Spacer(),
        Text(
          '${storm.participantUids.length} opted in',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (storm.status) {
      StormStatus.scheduled => _buildScheduled(context),
      StormStatus.active => _buildActive(context),
      StormStatus.survived => _buildSurvived(context),
      StormStatus.failed => _buildFailed(context),
    };
  }

  Widget _buildScheduled(BuildContext context) {
    final theme = Theme.of(context);
    final isParticipant =
        currentUid != null && storm.participantUids.contains(currentUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StormCountdown(targetTime: storm.scheduledStart, label: 'Starts in'),
        const SizedBox(height: 4),
        Text(
          '2x freshness decay for 48 hours. Keep health above '
          '${(storm.healthThreshold * 100).round()}% to earn 10 glory points.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (isParticipant)
              OutlinedButton(onPressed: onOptOut, child: const Text('Opt Out'))
            else
              FilledButton(onPressed: onOptIn, child: const Text('Opt In')),
          ],
        ),
      ],
    );
  }

  Widget _buildActive(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StormCountdown(targetTime: storm.scheduledEnd, label: 'Ends in'),
        const SizedBox(height: 8),
        // Health threshold indicator
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Threshold: ${(storm.healthThreshold * 100).round()}%',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (storm.lowestHealth != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Lowest: ${(storm.lowestHealth! * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            storm.lowestHealth! >= storm.healthThreshold
                                ? Colors.green
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.thunderstorm,
              size: 32,
              color: Colors.deepPurple.withValues(alpha: 0.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSurvived(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Health held at ${((storm.lowestHealth ?? 1.0) * 100).round()}%. '
            '+10 glory points to all ${storm.participantUids.length} participants!',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'Health dropped to ${((storm.lowestHealth ?? 0.0) * 100).round()}%, '
      'below the ${(storm.healthThreshold * 100).round()}% threshold. '
      'Better luck next time!',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Color _statusColor() {
    return switch (storm.status) {
      StormStatus.scheduled => Colors.amber,
      StormStatus.active => Colors.deepPurple,
      StormStatus.survived => Colors.green,
      StormStatus.failed => Colors.red,
    };
  }
}

class _StormCountdown extends StatefulWidget {
  const _StormCountdown({required this.targetTime, required this.label});

  final DateTime targetTime;
  final String label;

  @override
  State<_StormCountdown> createState() => _StormCountdownState();
}

class _StormCountdownState extends State<_StormCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.targetTime.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      return Text(
        'Now!',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      );
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final text = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Text(
      '${widget.label}: $text',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
