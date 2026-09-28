// Filesystem operations intentionally exercise the asynchronous cache paths.
// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/utils/transient_files.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  DefaultCacheManager? cache;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('md-cache-test-'),
  );
  tearDown(() async {
    await cache?.dispose();
    cache = null;
    await root.delete(recursive: true);
  });

  Future<DefaultCacheManager> open({
    int limit = 256,
    Duration grace = Duration.zero,
  }) async {
    return cache = await DefaultCacheManager.init(
      maxNrOfCacheLength: limit,
      readGracePeriod: grace,
      cacheDirectoryProvider: () async => root,
      httpClientFactory: () =>
          IOClient(_LocalHttpOverrides().createHttpClient(null)),
    );
  }

  test('live budget evicts older images and retains recent content', () async {
    final manager = await open();
    final older = await manager.putFile(
      'https://test/a',
      List.filled(120, 1),
      key: 'a',
      fileExtension: 'png',
    );
    final newer = await manager.putFile(
      'https://test/b',
      List.filled(120, 2),
      key: 'b',
      fileExtension: 'png',
    );
    expect((await manager.getFileFromCache('b'))!.file.path, newer.path);
    await manager.setMaxCacheLength(150);
    expect(await older.exists(), isFalse);
    expect(await newer.readAsBytes(), List.filled(120, 2));
    expect(manager.getTotalLength(), 120);
    // Metadata and disk paths agree when clearing putFile/resized entries.
    await manager.emptyCache();
    expect(await newer.exists(), isFalse);
    expect(manager.getTotalLength(), 0);
  });

  test('reads retain a grace period before explicit cleanup', () async {
    final manager = await open(grace: const Duration(milliseconds: 60));
    final file = await manager.putFile('https://test/a', [1, 2, 3], key: 'a');
    await manager.emptyCache();
    expect(await file.exists(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await manager.trimCache();
    expect(await file.exists(), isFalse);
  });

  test('a cache clear cannot remove a download in flight', () async {
    final manager = await open();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final started = Completer<void>();
    final finish = Completer<void>();
    server.listen((request) async {
      request.response.add([1, 2]);
      await request.response.flush();
      started.complete();
      await finish.future;
      request.response.add([3, 4]);
      await request.response.close();
    });
    try {
      final downloading = manager.getSingleFile(
        'http://127.0.0.1:${server.port}/image.png',
      );
      await started.future;
      await manager.emptyCache();
      finish.complete();
      expect(await (await downloading).readAsBytes(), [1, 2, 3, 4]);
    } finally {
      if (!finish.isCompleted) finish.complete();
      await server.close(force: true);
    }
  });

  test('serialized clear and write preserve the new file', () async {
    final manager = await open();
    await manager.putFile('https://test/old', [1], key: 'old');
    await Future.wait([
      manager.emptyCache(),
      manager.putFile('https://test/new', [2, 3], key: 'new'),
    ]);
    expect(await manager.getFileFromCache('old'), isNull);
    expect(await (await manager.getFileFromCache('new'))!.file.readAsBytes(), [
      2,
      3,
    ]);
  });

  test('old orphan files are reclaimed, fresh partial files survive', () async {
    final manager = await open();
    final old = await File('${manager.cacheDir}/orphan.png').writeAsBytes([1]);
    await old.setLastModified(DateTime.now().subtract(const Duration(days: 2)));
    final fresh = await File('${manager.cacheDir}/current.tmp')
        .writeAsBytes([2]);
    await manager.trimCache();
    expect(await old.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });

  test(
    'temporary cleanup preserves active leases, links and offline files',
    () async {
      final store = TransientFileStore(Directory('${root.path}/transient'));
      final active = await store.create('export');
      final source = await File('${active.path}/video.mp4')
          .writeAsBytes([1, 2]);
      final inactive = await File('${store.root.path}/abandoned.tmp')
          .writeAsBytes([3, 4, 5]);
      final offline = await File('${root.path}/offline.mp4').writeAsBytes([9]);
      await Link('${store.root.path}/outside').create(offline.path);
      expect(await store.prune(allInactive: true), 3);
      expect(await source.exists(), isTrue);
      expect(await inactive.exists(), isFalse);
      expect(await offline.readAsBytes(), [9]);
      expect(await TransientFileStore.sizeOf(store.root), 2);
      await store.release(active);
      expect(await active.exists(), isFalse);
    },
  );

  test(
    'legacy cleanup is age limited and never traverses plugin directories',
    () async {
      final old = await File('${root.path}/video_old.mp4').writeAsBytes([1]);
      await old.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      final recent = await File('${root.path}/video_recent.mp4')
          .writeAsBytes([2]);
      final plugin = await Directory('${root.path}/WebKit').create();
      final login = await File('${plugin.path}/state').writeAsBytes([3]);
      await TransientFileStore.pruneLegacy(root);
      expect(await old.exists(), isFalse);
      expect(await recent.exists(), isTrue);
      expect(await login.readAsBytes(), [3]);
    },
  );
}

class _LocalHttpOverrides extends HttpOverrides {}
