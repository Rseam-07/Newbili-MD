import 'dart:io';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

String webDownloadFilename(Uri url, String? suggestion) {
  var name = suggestion?.trim() ?? '';
  if (name.isEmpty || name == 'null') name = url.pathSegments.lastOrNull ?? '';
  try {
    name = Uri.decodeComponent(name);
  } catch (_) {}
  name = name.replaceAll(RegExp(r'[\\/\x00-\x1f\x7f]'), '_');
  if (name.isEmpty || name == '.' || name == '..') name = '下载文件';
  // Keep the extension; prevent excessive UTF-8 path component lengths.
  if (name.runes.length > 70) {
    name = String.fromCharCodes(
      name.runes.toList().sublist(name.runes.length - 70),
    );
  }
  return name;
}

abstract final class IosFileDownload {
  static bool _busy = false;

  static Future<void> save({
    required Uri url,
    required String filename,
    required String userAgent,
    required String cookie,
  }) async {
    if (_busy) {
      SmartDialog.showToast('请先完成当前下载');
      return;
    }
    if (url.scheme != 'https' && url.scheme != 'http') {
      SmartDialog.showToast('该下载链接暂不支持，请在浏览器中打开');
      return;
    }
    _busy = true;
    final token = CancelToken();
    // Web cookies are scoped to this exact origin, never forwarded to a CDN.
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        followRedirects: false,
        headers: {
          'User-Agent': userAgent,
          if (cookie.isNotEmpty) 'Cookie': cookie,
        },
      ),
    );
    Directory? temp;
    var downloading = true;
    try {
      temp = await Directory(tmpDirPath).createTemp('web-download-');
      final file = File('${temp.path}/${webDownloadFilename(url, filename)}');
      SmartDialog.showLoading(
        msg: '正在下载文件',
        clickMaskDismiss: true,
        onDismiss: () {
          if (downloading) token.cancel();
        },
      );
      var target = url;
      for (var hop = 0; ; hop++) {
        final response = await client.download(
          target.toString(),
          file.path,
          cancelToken: token,
          options: Options(
            validateStatus: (s) =>
                s == 200 || (s != null && s >= 300 && s < 400),
          ),
        );
        if (response.statusCode == 200) break;
        final location = response.headers.value('location');
        if (hop >= 5 || location == null) {
          throw const FormatException('下载链接跳转异常');
        }
        final next = target.resolve(location);
        if (next.scheme != 'https' && next.scheme != 'http' ||
            target.scheme == 'https' && next.scheme != 'https') {
          throw const FormatException('下载链接跳转异常');
        }
        if (next.origin != target.origin) {
          client.options.headers.remove('Cookie');
        }
        target = next;
      }
      if (token.isCancelled) return;
      downloading = false;
      await SmartDialog.dismiss(status: SmartStatus.loading);
      final saved = await const MethodChannel('com.rseam07.newbili/platform')
          .invokeMethod<bool>('exportFile', file.path);
      SmartDialog.showToast(saved == true ? '已保存到文件' : '已取消保存');
    } catch (error) {
      SmartDialog.showToast(token.isCancelled ? '已取消下载' : '文件保存失败，请重试');
    } finally {
      downloading = false;
      await SmartDialog.dismiss(status: SmartStatus.loading);
      client.close(force: true);
      _busy = false;
      try {
        if (temp != null && temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
