import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// A wrapper that adds horizontal swipe-to-rate gestures around a quiz card.
///
/// Swipe direction and velocity map to FSRS ratings:
/// - Left → Again
/// - Gentle right (< 500 px/s) → Hard
/// - Confident right (500–1500 px/s) → Good
/// - Fling right (≥ 1500 px/s) → Easy
///
/// Set [enabled] to false on desktop to disable gesture detection.
class SwipeableQuizCard extends StatefulWidget {
  const SwipeableQuizCard({
    required this.child,
    required this.onRate,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final ValueChanged<FsrsRating> onRate;
  final bool enabled;

  /// Minimum drag as a fraction of card width to trigger a rating.
  static const minDragFraction = 0.15;

  /// Velocity thresholds (px/s) for right-swipe rating zones.
  static const hardVelocityMax = 500.0;
  static const goodVelocityMax = 1500.0;

  @override
  State<SwipeableQuizCard> createState() => _SwipeableQuizCardState();
}

class _SwipeableQuizCardState extends State<SwipeableQuizCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _dragX = 0;
  double _startDragX = 0;
  double _cardWidth = 400; // Updated by LayoutBuilder on each build.
  FsrsRating? _pendingRating;
  bool _isFlying = false;
  bool _hasTriggeredThresholdHaptic = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Velocity → Rating resolution
  // ---------------------------------------------------------------------------

  FsrsRating _resolveRating(double dragX, double velocity) {
    if (dragX < 0) return FsrsRating.again;
    if (velocity.abs() >= SwipeableQuizCard.goodVelocityMax) {
      return FsrsRating.easy;
    }
    if (velocity.abs() >= SwipeableQuizCard.hardVelocityMax) {
      return FsrsRating.good;
    }
    return FsrsRating.hard;
  }

  /// Label to preview during drag. For right drags, displacement serves as a
  /// proxy for velocity zones (small → Hard, medium → Good, large → Easy).
  /// Not perfectly accurate since the actual rating uses release velocity, but
  /// gives the user a useful signal about which zone they're approaching.
  String _previewLabel(double dragX, double cardWidth) {
    if (dragX < 0) return 'Again';
    final fraction = dragX / cardWidth;
    if (fraction <= 0.25) return 'Hard';
    if (fraction <= 0.45) return 'Good';
    return 'Easy';
  }

  Color _overlayColor(double dragX, double normalizedDrag, double cardWidth) {
    final opacity = normalizedDrag.abs().clamp(0.0, 1.0) * 0.3;
    if (dragX < 0) return Colors.red.withValues(alpha: opacity);
    // Zone-based color: orange (Hard) → light green (Good) → green (Easy).
    final fraction = dragX / cardWidth;
    if (fraction <= 0.25) return Colors.orange.withValues(alpha: opacity);
    if (fraction <= 0.45) return Colors.lightGreen.withValues(alpha: opacity);
    return Colors.green.withValues(alpha: opacity);
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    _controller.stop();
    _startDragX = _dragX;
    _hasTriggeredThresholdHaptic = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final limit = _cardWidth * 0.9;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(-limit, limit);
    });

    // Haptic when crossing the commitment threshold.
    final threshold = _cardWidth * SwipeableQuizCard.minDragFraction;
    if (!_hasTriggeredThresholdHaptic && _dragX.abs() > threshold) {
      _hasTriggeredThresholdHaptic = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final threshold = _cardWidth * SwipeableQuizCard.minDragFraction;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragX.abs() > threshold) {
      // Commit to a rating — fly off.
      _pendingRating = _resolveRating(_dragX, velocity);
      _isFlying = true;
      HapticFeedback.mediumImpact();
      _controller.forward(from: 0);
    } else {
      // Spring back — insufficient drag.
      _pendingRating = null;
      _isFlying = false;
      _startDragX = _dragX;
      _controller.forward(from: 0);
    }
  }

  void _onDragCancel() {
    setState(() {
      _dragX = 0;
      _isFlying = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Animation
  // ---------------------------------------------------------------------------

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    if (_isFlying && _pendingRating != null) {
      final rating = _pendingRating!;
      // Reset fields before calling onRate — the callback may trigger a
      // provider state update that rebuilds the tree and disposes this widget.
      // Field assignments on a disposed State are harmless but confusing to
      // read, so we do them first.
      _pendingRating = null;
      _isFlying = false;
      _dragX = 0;
      if (mounted) {
        widget.onRate(rating);
      }
    } else {
      // Spring-back completed.
      setState(() {
        _dragX = 0;
        _isFlying = false;
      });
    }
  }

  double _currentOffset(double cardWidth) {
    if (!_controller.isAnimating && !_controller.isCompleted) return _dragX;

    final t = _controller.value;
    if (_isFlying) {
      // Fly off-screen in the swipe direction.
      final target = cardWidth * 1.5 * _dragX.sign;
      return _dragX + (target - _dragX) * Curves.easeIn.transform(t);
    } else {
      // Spring back to center.
      return _startDragX * (1.0 - Curves.easeOut.transform(t));
    }
  }

  double _currentOpacity() {
    if (!_isFlying) return 1.0;
    // Fade out over the last 30% of the fly-off animation.
    final t = _controller.value;
    if (t < 0.7) return 1.0;
    return 1.0 - ((t - 0.7) / 0.3);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        _cardWidth = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = _currentOffset(_cardWidth);
              final normalizedDrag =
                  _cardWidth > 0 ? offset / (_cardWidth * 0.4) : 0.0;
              final rotation = offset / _cardWidth * 0.1;
              final opacity = _currentOpacity();
              final threshold = _cardWidth * SwipeableQuizCard.minDragFraction;
              final pastThreshold = offset.abs() > threshold;

              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.identity()
                        ..translateByDouble(offset, 0, 0, 1)
                        ..rotateZ(rotation),
                  child: Stack(
                    children: [
                      child!,
                      // Color overlay.
                      if (offset.abs() > 1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _overlayColor(
                                  offset,
                                  normalizedDrag,
                                  _cardWidth,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      // Rating label hint.
                      if (pastThreshold && !_isFlying)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              _previewLabel(offset, _cardWidth),
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color:
                                    offset < 0
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}
