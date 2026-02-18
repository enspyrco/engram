import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the current UTC time.
///
/// Override in tests with a fixed time:
/// ```dart
/// container.updateOverrides([
///   clockProvider.overrideWithValue(() => DateTime.utc(2026, 1, 15)),
/// ]);
/// ```
final clockProvider = Provider<DateTime Function()>(
  (ref) => () => DateTime.now().toUtc(),
);
