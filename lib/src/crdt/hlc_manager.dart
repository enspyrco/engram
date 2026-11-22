import 'package:crdt/crdt.dart';

/// Manages a Hybrid Logical Clock (HLC) for this device.
///
/// The HLC is the foundation of CRDT ordering — it combines wall-clock time
/// with a logical counter to produce timestamps that are:
/// - Monotonically increasing (even if wall clock goes backward)
/// - Globally unique (via node ID)
/// - Causally ordered (via merge with remote HLCs)
///
/// Use [now] to stamp local events and [receive] to reconcile with
/// incoming remote timestamps during sync.
class HlcManager {
  HlcManager({required String nodeId}) : _canonicalTime = Hlc.zero(nodeId);

  Hlc _canonicalTime;

  /// The highest HLC this device has seen (local or remote).
  Hlc get canonicalTime => _canonicalTime;

  /// The device's node ID.
  String get nodeId => _canonicalTime.nodeId;

  /// Generates a new HLC for a local event.
  ///
  /// The returned timestamp is guaranteed to be strictly greater than
  /// any previous [now] or [receive] result.
  ///
  /// Pass [wallTime] to override the system clock (useful in tests).
  Hlc now({DateTime? wallTime}) {
    _canonicalTime = _canonicalTime.increment(wallTime: wallTime);
    return _canonicalTime;
  }

  /// Merges a remote HLC with the local clock.
  ///
  /// Returns a new HLC that is at least as high as both the local
  /// canonical time and the [remote] timestamp, preserving monotonicity.
  ///
  /// Pass [wallTime] to override the system clock (useful in tests).
  Hlc receive(Hlc remote, {DateTime? wallTime}) {
    // This device's own clock coming back, as when the log is replayed after
    // the database was lost: Hlc.merge rejects its own node, but the clock
    // must still not fall behind it.
    if (remote.nodeId == nodeId) {
      if (remote > _canonicalTime) _canonicalTime = remote;
      return _canonicalTime;
    }
    _canonicalTime = _canonicalTime.merge(remote, wallTime: wallTime);
    return _canonicalTime;
  }
}
