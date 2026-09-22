import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/services/download/download_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  _Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late File file;
  late Dio client;
  late int completions;
  Object? failure;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('md-download-test-');
    file = File('${dir.path}/video.m4s');
    client = Dio();
    completions = 0;
    failure = null;
  });
  tearDown(() async {
    client.close(force: true);
    await dir.delete(recursive: true);
  });
  DownloadManager start() => DownloadManager(
    url: 'https://example.test/media',
    path: file.path,
    client: client,
    onReceiveProgress: null,
    onDone: ([error]) {
      completions++;
      failure = error;
    },
  );
  void response(int code, String text, {String? range, int? length}) {
    client.httpClientAdapter = _Adapter(
      (request) async => ResponseBody.fromString(
        text,
        code,
        headers: {
          Headers.contentLengthHeader: ['${length ?? text.length}'],
          if (range != null) 'content-range': [range],
        },
      ),
    );
  }

  test(
    'a CDN ignoring Range replaces the old prefix rather than appending',
    () async {
      await file.writeAsString('old');
      response(200, 'new-file');
      final download = start();
      await download.task;
      expect(await file.readAsString(), 'new-file');
      expect(download.status, DownloadStatus.completed);
      expect(failure, isNull);
      expect(completions, 1);
    },
  );
  test('valid partial response resumes exactly at the saved byte', () async {
    await file.writeAsString('abc');
    client.httpClientAdapter = _Adapter((request) async {
      expect(request.headers['range'], 'bytes=3-');
      return ResponseBody.fromString(
        'def',
        206,
        headers: {
          'content-range': ['bytes 3-5/6'],
          'content-length': ['3'],
        },
      );
    });
    final download = start();
    await download.task;
    expect(await file.readAsString(), 'abcdef');
    expect(download.status, DownloadStatus.completed);
    expect(completions, 1);
  });
  test(
    'a mismatched range is rejected before any local bytes change',
    () async {
      await file.writeAsString('abc');
      response(206, 'abcdef', range: 'bytes 0-5/6');
      final download = start();
      await download.task;
      expect(await file.readAsString(), 'abc');
      expect(download.status, DownloadStatus.failDownload);
      expect(failure, isA<FormatException>());
    },
  );
  test(
    '416 only completes when the advertised length exactly matches',
    () async {
      await file.writeAsString('abcdef');
      response(416, 'range error', range: 'bytes */6');
      final download = start();
      await download.task;
      expect(await file.readAsString(), 'abcdef');
      expect(download.status, DownloadStatus.completed);
      expect(failure, isNull);
    },
  );
  test('invalid 416 never appends an error page or reports success', () async {
    await file.writeAsString('abc');
    response(416, '<html>error</html>', range: 'bytes */2');
    final download = start();
    await download.task;
    expect(await file.readAsString(), 'abc');
    expect(download.status, DownloadStatus.failDownload);
    expect(completions, 1);
  });
  test(
    'a short response preserves the prefix but is not a completed video',
    () async {
      response(200, 'abc', length: 6);
      final download = start();
      await download.task;
      expect(await file.readAsString(), 'abc');
      expect(download.status, DownloadStatus.failDownload);
      expect(failure, isNotNull);
    },
  );
  test(
    'network failure before headers keeps already downloaded bytes',
    () async {
      await file.writeAsString('abc');
      client.httpClientAdapter = _Adapter(
        (r) async => throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        ),
      );
      final download = start();
      await download.task;
      expect(await file.readAsString(), 'abc');
      expect(download.status, DownloadStatus.failDownload);
      expect(completions, 1);
    },
  );
  test(
    'cancel during response startup cannot overwrite or complete the file',
    () async {
      await file.writeAsString('abc');
      final requested = Completer<void>();
      final incoming = Completer<ResponseBody>();
      client.httpClientAdapter = _Adapter((_) {
        requested.complete();
        return incoming.future;
      });
      final download = start();
      await requested.future;
      final cancelled = download.cancel(isDelete: false);
      incoming.complete(ResponseBody.fromString('abcdef', 200));
      await cancelled;
      expect(await file.readAsString(), 'abc');
      expect(download.status, DownloadStatus.pause);
      expect(failure, isNotNull);
      expect(completions, 1);
    },
  );
  test('delete cancellation removes only its partial file', () async {
    await file.writeAsString('abc');
    response(206, 'def', range: 'bytes 3-5/6');
    final download = start();
    await download.cancel(isDelete: true);
    expect(file.existsSync(), isFalse);
    expect(download.status, DownloadStatus.pause);
    expect(completions, 1);
  });
}
