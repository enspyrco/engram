import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Pre-loads team member profile photos as [ui.Image] objects for direct
/// canvas rendering via [Canvas.drawImageRect].
///
/// Falls back gracefully — if a photo fails to load, [getAvatar] returns null
/// and the painter renders an initial-letter circle instead.
class TeamAvatarCache {
  final _cache = <String, ui.Image>{};
  final _loading = <String, Completer<ui.Image?>>{};

  /// Get a cached avatar image, or null if not yet loaded.
  ui.Image? getAvatar(String uid) => _cache[uid];

  /// Start loading an avatar from a URL. Calls [onLoaded] when ready.
  void loadAvatar({
    required String uid,
    required String url,
    VoidCallback? onLoaded,
  }) {
    if (_cache.containsKey(uid) || _loading.containsKey(uid)) return;

    final completer = Completer<ui.Image?>();
    _loading[uid] = completer;

    final imageStream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _cache[uid] = info.image;
        _loading.remove(uid);
        imageStream.removeListener(listener);
        completer.complete(info.image);
        onLoaded?.call();
      },
      onError: (error, _) {
        _loading.remove(uid);
        imageStream.removeListener(listener);
        completer.complete(null);
      },
    );
    imageStream.addListener(listener);
  }

  /// Whether all requested avatars have finished loading (or failed).
  bool get isFullyLoaded => _loading.isEmpty;

  void dispose() {
    _cache.clear();
    _loading.clear();
  }
}
