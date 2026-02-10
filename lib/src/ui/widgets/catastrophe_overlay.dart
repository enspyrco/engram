import 'package:flutter/material.dart';

import '../../models/network_health.dart';
import '../../providers/catastrophe_provider.dart';

/// Full-screen overlay for dramatic catastrophe events.
///
/// Appears during tier transitions with appropriate messaging and visual
/// effects. Auto-dismisses after a timeout or on tap.
class CatastropheOverlay extends StatefulWidget {
  const CatastropheOverlay({
    required this.transition,
    required this.onDismiss,
    super.key,
  });

  final TierTransition transition;
  final VoidCallback onDismiss;

  @override
  State<CatastropheOverlay> createState() => _CatastropheOverlayState();
}

class _CatastropheOverlayState extends State<CatastropheOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
    );
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.transition.to;
    final isWorsening = widget.transition.isWorsening;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = _fadeIn.value * (1.0 - _fadeOut.value);

          return Opacity(
            opacity: opacity,
            child: Container(
              color: _overlayColor(tier, isWorsening),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForTier(tier, isWorsening),
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _titleForTransition(tier, isWorsening),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _subtitleForTransition(tier, isWorsening),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _overlayColor(HealthTier tier, bool isWorsening) {
    if (!isWorsening) return Colors.green.withValues(alpha: 0.85);

    switch (tier) {
      case HealthTier.healthy:
        return Colors.green.withValues(alpha: 0.85);
      case HealthTier.brownout:
        return Colors.amber.shade900.withValues(alpha: 0.85);
      case HealthTier.cascade:
        return Colors.deepOrange.shade900.withValues(alpha: 0.9);
      case HealthTier.fracture:
        return Colors.red.shade900.withValues(alpha: 0.92);
      case HealthTier.collapse:
        return Colors.black.withValues(alpha: 0.95);
    }
  }

  IconData _iconForTier(HealthTier tier, bool isWorsening) {
    if (!isWorsening) return Icons.celebration;

    switch (tier) {
      case HealthTier.healthy:
        return Icons.check_circle;
      case HealthTier.brownout:
        return Icons.lightbulb_outline;
      case HealthTier.cascade:
        return Icons.warning;
      case HealthTier.fracture:
        return Icons.flash_on;
      case HealthTier.collapse:
        return Icons.nightlight_round;
    }
  }

  String _titleForTransition(HealthTier tier, bool isWorsening) {
    if (!isWorsening) return 'NETWORK RECOVERING';

    switch (tier) {
      case HealthTier.healthy:
        return 'ALL CLEAR';
      case HealthTier.brownout:
        return 'BROWNOUT';
      case HealthTier.cascade:
        return 'CASCADE WARNING';
      case HealthTier.fracture:
        return 'NETWORK FRACTURE';
      case HealthTier.collapse:
        return 'TOTAL COLLAPSE';
    }
  }

  String _subtitleForTransition(HealthTier tier, bool isWorsening) {
    if (!isWorsening) {
      return 'The team is bringing the network back online.';
    }

    switch (tier) {
      case HealthTier.healthy:
        return 'The network is stable.';
      case HealthTier.brownout:
        return 'Some concepts are fading. Review them before they disconnect.';
      case HealthTier.cascade:
        return 'The network is destabilizing. '
            'Critical concepts are at risk of disconnection.';
      case HealthTier.fracture:
        return 'The network has split apart. '
            'A Repair Mission has been generated. Rally the team!';
      case HealthTier.collapse:
        return 'The network has gone dark. '
            'But one spark remains. Begin the Rekindling.';
    }
  }
}
