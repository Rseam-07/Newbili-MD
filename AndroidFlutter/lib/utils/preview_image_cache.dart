import 'dart:ui' as ui;

/// The cache owns originals; each viewer receives a clone it must dispose.
/// Eviction therefore cannot invalidate an image that is currently painting.
class PreviewImageCache {
  PreviewImageCache({this.maxBytes = 24 << 20, this.maxEntries = 3});
  final int maxBytes;
  final int maxEntries;
  final _images = <String, ui.Image>{};
  final _pending = <String, Future<void>>{};
  int _generation = 0;
  int get bytes =>
      _images.values.fold(0, (sum, i) => sum + i.width * i.height * 4);
  int get length => _images.length;

  Future<ui.Image?> load(
    String key,
    Future<ui.Image?> Function() loader,
  ) async {
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return cached.clone();
    }
    final generation = _generation;
    final pending = _pending[key] ??= _load(key, generation, loader);
    try {
      await pending;
      if (generation != _generation) return null;
      return _images[key]?.clone();
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }

  Future<void> _load(
    String key,
    int generation,
    Future<ui.Image?> Function() loader,
  ) async {
    final image = await loader();
    if (image == null) return;
    if (generation != _generation) {
      image.dispose();
      return;
    }
    _images[key] = image;
    // Keep a single oversized sprite available for the current scrub gesture.
    while (_images.length > 1 &&
        (_images.length > maxEntries || bytes > maxBytes)) {
      _images.remove(_images.keys.first)!.dispose();
    }
  }

  void clear() {
    _generation++;
    _pending.clear();
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
