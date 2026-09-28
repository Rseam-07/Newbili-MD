import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/transient_files.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class CacheUsage {
  const CacheUsage({required this.images, required this.temporary});
  final int images;
  final int temporary;
  int get total => images + temporary;
}

abstract final class CacheManager {
  static late final DefaultCacheManager manager;
  static late final TransientFileStore temporary;
  static Future<CacheUsage>? _scan;
  static Future<void>? _cleaning;

  static Future<void> ensureInitialized() async {
    final temp = await getTemporaryDirectory();
    temporary = TransientFileStore(
      Directory(path.join(temp.path, 'newbili-transient')),
    );
    manager = await DefaultCacheManager.init(
      maxNrOfCacheLength: Pref.maxCacheSize.toInt(),
      connectionParameters: ConnectionParameters(
        connectionTimeout: const Duration(seconds: 15),
        requestTimeout: const Duration(seconds: 30),
      ),
    );
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 64 << 20
      ..maximumSize = 256;
    unawaited(_maintainTemporary(temp));
  }

  static Future<void> _maintainTemporary(Directory temp) async {
    try {
      await temporary.prune();
      await TransientFileStore.pruneLegacy(temp);
    } catch (error) {
      if (kDebugMode) debugPrint('Temporary cache maintenance: $error');
    }
  }

  static Future<void> setLimit(int bytes) async {
    if (bytes < (32 << 20) || bytes > (2048 << 20)) {
      throw ArgumentError('缓存上限须在 32–2048 MB 之间');
    }
    await _scan;
    final previous = manager.maxNrOfCacheLength;
    await manager.setMaxCacheLength(bytes);
    try {
      await GStorage.setting.put(SettingBoxKey.maxCacheSize, bytes);
    } catch (_) {
      await manager.setMaxCacheLength(previous);
      rethrow;
    }
  }

  static Future<CacheUsage> usage() =>
      _scan ??= _readUsage().whenComplete(() => _scan = null);

  static Future<CacheUsage> _readUsage() async {
    // Directory traversal stays off the animation/UI isolate.
    final sizes = await compute(_measure, [
      manager.cacheDir,
      temporary.root.path,
    ]);
    return CacheUsage(images: sizes[0], temporary: sizes[1]);
  }

  static Future<List<int>> _measure(List<String> directories) async => [
    for (final directory in directories)
      await TransientFileStore.sizeOf(Directory(directory)),
  ];

  static Future<int> loadApplicationCache() async => (await usage()).total;

  static String formatSize(num value) {
    if (!value.isFinite || value < 0) value = 0;
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      index++;
      value /= 1024;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }

  static Future<void> clearLibraryCache() =>
      _cleaning ??= _clear().whenComplete(() => _cleaning = null);

  static Future<void> _clear() async {
    await _scan;
    // Visible images retain their live handles. Offline videos and WebView
    // login state are outside both owned cache directories.
    PaintingBinding.instance.imageCache.clear();
    await manager.emptyCache();
    await temporary.prune(allInactive: true);
  }
}
