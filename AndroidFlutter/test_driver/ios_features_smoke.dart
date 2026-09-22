// Native integration check; not the shipping entry point.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/main.dart' as app;
import 'package:PiliPlus/pages/main/view.dart';
import 'package:PiliPlus/pages/setting/pages/font_setting.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

Future<void> main() async {
  await app.main();
  final controller = LiveWidgetController(WidgetsBinding.instance);
  final status = ValueNotifier('MD_FEATURE_RUNNING');
  final captures = GlobalKey();
  final failures = <String>[];
  final results = <String, Object?>{};
  final originalError = FlutterError.onError;
  FlutterError.onError = (error) {
    failures.add(error.exceptionAsString());
    originalError?.call(error);
  };
  final output = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/ios-features',
  );
  await output.create(recursive: true);
  runApp(RepaintBoundary(key: captures, child: const app.MyApp()));

  Future<void> waitFor(bool Function() condition, String name) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await controller.pump(const Duration(milliseconds: 200));
    }
    if (!condition()) throw StateError('Timeout: $name');
  }

  Future<void> capture(String name) async {
    await controller.pump(const Duration(milliseconds: 400));
    final boundary =
        captures.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${output.path}/$name.png')
        .writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  }

  try {
    await controller.pump(const Duration(seconds: 1));
    final skip = find.byKey(const ValueKey('onboarding-skip'));
    if (skip.evaluate().isNotEmpty) await controller.tap(skip);
    await waitFor(() => find.byType(MainApp).evaluate().isNotEmpty, 'home');
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 8,
        bottom: 8,
        child: ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (_, label, _) => Semantics(
            label: label,
            child: Text(
              label,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
    );
    Get.key.currentState!.overlay!.insert(overlay);
    const native = MethodChannel('com.rseam07.newbili/platform');
    final fonts = (await FontUtils.getFont()).toList()..sort();
    if (fonts.length < 20) throw StateError('iOS font enumeration empty');
    Get.to(() => const FontSettingPage());
    await waitFor(
      () => find.text(fonts.first).evaluate().isNotEmpty,
      'font rows',
    );
    await capture('01-fonts');
    results['fonts'] = {
      'count': fonts.length,
      'first': fonts.first,
      'screen': 'system list rendered',
    };
    Get.back();
    await controller.pump(const Duration(milliseconds: 500));

    if (!await Permission.photosAddOnly.isGranted) {
      throw StateError(
        'Grant photos-add to the dedicated simulator before running',
      );
    }
    final picture = ui.PictureRecorder();
    Canvas(picture).drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFFBB4168),
    );
    final recording = picture.endRecording();
    final sample = await recording.toImage(64, 64);
    final png = await sample.toByteData(format: ui.ImageByteFormat.png);
    final saved = await ImageUtils.saveByteImg(
      bytes: png!.buffer.asUint8List(),
      fileName: 'MD-native-save-check',
    );
    sample.dispose();
    recording.dispose();
    if (saved?.isSuccess != true) {
      throw StateError('Native photo write failed: ${saved?.errorMessage}');
    }
    results['photos'] =
        'native PhotoKit save succeeded with add-only permission';

    final brightness = ScreenBrightnessPlatform.instance;
    final original = await brightness.system;
    await brightness.setApplicationScreenBrightness(.35);
    if (!await brightness.hasApplicationScreenBrightnessChanged) {
      throw StateError('Application brightness was not set');
    }
    await brightness.resetApplicationScreenBrightness();
    if (await brightness.hasApplicationScreenBrightnessChanged) {
      throw StateError('Application brightness was not reset');
    }
    final after = await brightness.system;
    if ((after - original).abs() > .02) {
      throw StateError('System brightness changed');
    }
    results['brightness'] =
        'app override resets; original system brightness retained';

    final export = File('${output.path}/MD-export-check.txt');
    await export.writeAsString('Newbili MD: native Files export.\n');
    status.value = 'MD_FEATURE_EXPORT_CANCEL';
    final cancelled = await native.invokeMethod<bool>(
      'exportFile',
      export.path,
    );
    if (cancelled != false) {
      throw StateError('Picker cancellation did not return false');
    }
    results['exportCancel'] = 'native document picker cancellation resolved';
    // Wait for UIKit dismissal to complete before opening another document picker.
    await controller.pump(const Duration(milliseconds: 700));
    status.value = 'MD_FEATURE_EXPORT_SAVE';
    final exported = await native.invokeMethod<bool>('exportFile', export.path);
    if (exported != true) throw StateError('Native export was not saved');
    results['exportSave'] = 'native document picker reported a saved file';
    await controller.pump(const Duration(milliseconds: 500));
    await capture('02-return');
    status.value = failures.isEmpty ? 'MD_FEATURE_PASSED' : 'MD_FEATURE_FAILED';
  } catch (error, stack) {
    failures.add('$error\n$stack');
    status.value = 'MD_FEATURE_FAILED';
  } finally {
    results['errors'] = failures;
    results['status'] = failures.isEmpty ? 'passed' : 'failed';
    await File('${output.path}/report.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    debugPrint('MD_FEATURE_REPORT:${jsonEncode(results)}');
  }
}
