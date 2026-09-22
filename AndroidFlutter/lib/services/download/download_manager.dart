import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:dio/dio.dart';

/// Streams to disk and validates the server's range before appending anything.
/// A network failure preserves the verified prefix for the next attempt.
class DownloadManager {
  final String url;
  final String path;
  final void Function(int, int)? onReceiveProgress;
  final void Function([Object? error]) onDone;
  final Dio? client;

  DownloadStatus _status = DownloadStatus.downloading;
  DownloadStatus get status => _status;
  final _cancelToken = CancelToken();
  bool _deleteOnCancel = false;
  late final Future<void> task;

  DownloadManager({
    required this.url,
    required this.path,
    required this.onReceiveProgress,
    required this.onDone,
    this.client,
  }) {
    task = _start();
  }

  static final _partialRange = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$');
  static final _completeRange = RegExp(r'^bytes \*/(\d+)$');

  void _checkCancelled() {
    if (_cancelToken.cancelError case final error?) throw error;
  }

  Future<void> _start() async {
    final file = File(path);
    IOSink? sink;
    Object? failure;
    try {
      await file.parent.create(recursive: true);
      var received = file.existsSync() ? await file.length() : 0;
      _checkCancelled();
      final response = await (client ?? Request.http11Dio).get<ResponseBody>(
        url.http2https,
        options: Options(
          headers: {'range': 'bytes=$received-', 'accept-encoding': 'identity'},
          responseType: ResponseType.stream,
          validateStatus: (status) =>
              status == 200 || status == 206 || status == 416,
        ),
        cancelToken: _cancelToken,
      );
      final body = response.data!;
      final range = response.headers.value('content-range') ?? '';
      int total;
      if (response.statusCode == 416) {
        // A 416 is only complete when the server confirms the exact local size.
        await body.stream.listen(null).cancel();
        final match = _completeRange.firstMatch(range);
        if (received == 0 ||
            match == null ||
            int.parse(match[1]!) != received) {
          throw const FormatException('缓存长度与服务器不一致，请删除该缓存后重试');
        }
        total = received;
      } else {
        if (response.statusCode == 206) {
          final match = _partialRange.firstMatch(range);
          if (match == null ||
              int.parse(match[1]!) != received ||
              int.parse(match[2]!) < received ||
              int.parse(match[2]!) + 1 != int.parse(match[3]!)) {
            await body.stream.listen(null).cancel();
            throw const FormatException('服务器返回了无效的续传范围');
          }
          total = int.parse(match[3]!);
        } else {
          // The CDN ignored Range or the resource changed: restart, never append.
          received = 0;
          total = body.contentLength;
        }
        _checkCancelled();
        sink = file.openWrite(
          mode: received == 0 ? FileMode.writeOnly : FileMode.writeOnlyAppend,
        );
        onReceiveProgress?.call(received, total < 0 ? 0 : total);
        var last = 0;
        // addStream supplies disk backpressure and propagates write failures.
        await sink.addStream(
          body.stream.map((chunk) {
            _checkCancelled();
            if (total >= 0 && received + chunk.length > total) {
              throw const FormatException('下载内容超出服务器声明的长度');
            }
            received += chunk.length;
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - last >= 1000) {
              last = now;
              onReceiveProgress?.call(received, total < 0 ? 0 : total);
            }
            return chunk;
          }),
        );
        await sink.flush();
        await sink.close();
        sink = null;
        if (total >= 0 && received != total) {
          throw const FormatException('下载中断，已保留进度，可继续下载');
        }
      }
      _checkCancelled();
      onReceiveProgress?.call(received, received);
      _status = DownloadStatus.completed;
    } catch (error) {
      failure = error;
      if (_status == DownloadStatus.downloading) {
        _status = DownloadStatus.failDownload;
      }
    } finally {
      try {
        await sink?.close();
      } catch (error) {
        failure ??= error;
      }
      if (_deleteOnCancel && file.existsSync()) {
        try {
          await file.delete();
        } catch (error) {
          failure ??= error;
        }
      }
    }
    onDone(failure);
  }

  Future<void> cancel({required bool isDelete}) {
    if (_status == DownloadStatus.completed) return task;
    _deleteOnCancel |= isDelete;
    if (_status == DownloadStatus.downloading) _status = DownloadStatus.pause;
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    return task;
  }
}
