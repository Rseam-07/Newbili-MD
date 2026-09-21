import 'dart:async';

import 'package:dio/dio.dart';
import 'package:http2/http2.dart';

class RetryInterceptor extends Interceptor {
  final Dio _client;
  final int _count;
  final int _delay;

  RetryInterceptor(this._client, this._count, this._delay);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.responseType == ResponseType.stream) {
      return handler.next(err);
    }
    if (err.response != null) {
      final options = err.requestOptions;
      if (options.followRedirects && options.maxRedirects > 0) {
        final status = err.response!.statusCode;
        if (status != null && 300 <= status && status < 400) {
          var redirectUrl = err.response!.headers.value('location');
          if (redirectUrl != null) {
            var uri = Uri.parse(redirectUrl);
            if (!uri.hasScheme) {
              uri = options.uri.resolveUri(uri);
              redirectUrl = uri.toString();
            }
            (options..path = redirectUrl).maxRedirects--;
            if (status == 303) {
              options
                ..data = null
                ..method = 'GET';
            }
            _client
                .fetch(options)
                .then(
                  (i) => handler.resolve(
                    i
                      ..redirects.add(
                        RedirectRecord(status, options.method, uri),
                      )
                      ..isRedirect = true,
                  ),
                )
                .onError<DioException>((error, _) => handler.next(error));
            return;
          }
        }
      }
      return handler.next(err);
    } else {
      // A lost response does not mean a write failed. Never replay a publish,
      // coin or other mutation just because its acknowledgement was lost.
      if (!const {
        'GET',
        'HEAD',
        'OPTIONS',
      }.contains(err.requestOptions.method)) {
        return handler.next(err);
      }
      switch (err.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.unknown:
          if ((err.requestOptions.extra['_rt'] ??= 0) < _count &&
              err.error
                  is! TransportConnectionException // 网络中断, 此时请求可能已经被服务器所接收
                  ) {
            _retry(err, handler);
          } else {
            handler.next(err);
          }
          return;
        default:
          return handler.next(err);
      }
    }
  }

  Future<void> _retry(
    DioException original,
    ErrorInterceptorHandler handler,
  ) async {
    final options = original.requestOptions;
    final attempt = (options.extra['_rt'] as int? ?? 0) + 1;
    final ready = Completer<void>();
    final timer = Timer(Duration(milliseconds: attempt * _delay), () {
      if (!ready.isCompleted) ready.complete();
    });
    try {
      final cancel = options.cancelToken;
      if (cancel != null) {
        await Future.any<void>([
          ready.future,
          cancel.whenCancel.then((_) {}),
        ]);
        if (cancel.isCancelled) {
          handler.reject(cancel.cancelError!);
          return;
        }
      } else {
        await ready.future;
      }
      final response = await _client.fetch<dynamic>(
        options.copyWith(
          extra: {...options.extra, '_rt': attempt},
        ),
      );
      handler.resolve(response);
    } on DioException catch (error) {
      handler.reject(error);
    } catch (error, stack) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stack,
        ),
      );
    } finally {
      timer.cancel();
    }
  }

  RetryInterceptor copyWith({Dio? client, int? count, int? delay}) =>
      .new(client ?? _client, count ?? _count, delay ?? _delay);
}
