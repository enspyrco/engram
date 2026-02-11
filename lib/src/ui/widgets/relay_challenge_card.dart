import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/relay_challenge.dart';

/// A card displaying a relay challenge as a horizontal chain of concept legs.
///
/// Each leg shows its status via icon and color. Claimed legs display a
/// countdown timer. The "Claim" button is only enabled on the current
/// unclaimed leg (when the prior leg is complete).
class RelayChallengeCard extends StatelessWidget {
  const RelayChallengeCard({
    required this.relay,
    required this.currentUid,
    this.onClaimLeg,
    super.key,
  });

  final RelayChallenge relay;
  final String? currentUid;
  final void Function(int legIndex)? onClaimLeg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                const Icon(Icons.sync, size: 18, color: Colors.cyan),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    relay.title,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${relay.completedLegs}/${relay.legs.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Concept chain: horizontal scrollable row
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: relay.legs.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                ),
                itemBuilder: (context, index) => _LegChip(
                  leg: relay.legs[index],
                  index: index,
                  canClaim: _canClaim(index),
                  onClaim: onClaimLeg != null ? () => onClaimLeg!(index) : null,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: relay.progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: Colors.cyan,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canClaim(int index) {
    final leg = relay.legs[index];
    if (leg.status != RelayLegStatus.unclaimed) return false;
    if (index == 0) return true;
    return relay.legs[index - 1].completedAt != null;
  }
}

class _LegChip extends StatelessWidget {
  const _LegChip({
    required this.leg,
    required this.index,
    required this.canClaim,
    this.onClaim,
  });

  final RelayLeg leg;
  final int index;
  final bool canClaim;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _statusVisuals();

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  leg.conceptName,
                  style: theme.textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (leg.status == RelayLegStatus.claimed)
            _CountdownText(leg: leg)
          else if (leg.status == RelayLegStatus.stalled)
            Text(
              'Stalled!',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (canClaim)
            SizedBox(
              height: 24,
              child: TextButton(
                onPressed: onClaim,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Claim', style: TextStyle(fontSize: 10)),
              ),
            )
          else if (leg.claimedByName != null)
            Text(
              leg.claimedByName!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _statusVisuals() {
    return switch (leg.status) {
      RelayLegStatus.unclaimed => (Icons.radio_button_unchecked, Colors.grey),
      RelayLegStatus.claimed => (Icons.timer, Colors.cyan),
      RelayLegStatus.completed => (Icons.check_circle, Colors.green),
      RelayLegStatus.stalled => (Icons.warning_amber, Colors.amber),
    };
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.leg});

  final RelayLeg leg;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
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
    final deadline = widget.leg.deadline;
    if (deadline == null) return const SizedBox.shrink();

    final remaining = deadline.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      return Text(
        'Overdue!',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
      );
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return Text(
      '${hours}h ${minutes}m left',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.cyan,
          ),
    );
  }
}
