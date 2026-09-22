import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

abstract final class IosCaptcha {
  static const _channel = MethodChannel('com.rseam07.newbili/captcha');
  static bool _active = false;

  static Future<Map<String, dynamic>?> verify(
    String gt,
    String challenge,
  ) async {
    if (_active) return null;
    _active = true;
    try {
      return await _channel
          .invokeMapMethod<String, dynamic>('verify', {
            'gt': gt,
            'challenge': challenge,
          })
          .timeout(const Duration(minutes: 3));
    } on TimeoutException {
      await _channel.invokeMethod<void>('cancel');
      SmartDialog.showToast('验证已超时，请重新获取验证码');
      return null;
    } on PlatformException catch (error) {
      SmartDialog.showToast(error.message ?? '验证暂时不可用，请重试');
      return null;
    } finally {
      _active = false;
    }
  }
}
