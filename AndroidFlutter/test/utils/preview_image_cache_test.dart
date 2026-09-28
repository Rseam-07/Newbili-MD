import 'dart:async';
import 'dart:ui' as ui;

import 'package:PiliPlus/utils/preview_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFFB93A70), ui.BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(32, 32);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'preview eviction keeps displayed clones valid and bounds memory',
    () async {
      final cache = PreviewImageCache(maxEntries: 2, maxBytes: 8192);
      final first = (await cache.load('a', image))!;
      (await cache.load('b', image))!.dispose();
      (await cache.load('c', image))!.dispose();
      expect(cache.length, 2);
      expect(cache.bytes, 8192);
      expect(await first.toByteData(), isNotNull);
      cache.clear();
      expect(await first.toByteData(), isNotNull);
      first.dispose();
    },
  );
  test('late decode after leaving the player is discarded', () async {
    final cache = PreviewImageCache();
    final pending = Completer<ui.Image?>();
    final result = cache.load('a', () => pending.future);
    cache.clear();
    pending.complete(await image());
    expect(await result, isNull);
    expect(cache.length, 0);
  });
  test('concurrent viewers share decoding and own separate handles', () async {
    final cache = PreviewImageCache();
    var calls = 0;
    Future<ui.Image> decode() {
      calls++;
      return image();
    }

    final images = await Future.wait([
      cache.load('a', decode),
      cache.load('a', decode),
    ]);
    expect(calls, 1);
    images[0]!.dispose();
    expect(await images[1]!.toByteData(), isNotNull);
    images[1]!.dispose();
    cache.clear();
  });
}
