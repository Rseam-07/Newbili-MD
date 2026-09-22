// Targeted native smoke for the reported login, video controls and web link bugs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/main.dart' as app;
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/login/geetest/geetest_webview_dialog.dart';
import 'package:PiliPlus/pages/main/view.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/view.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/pages/webview/view.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/web_link.dart';
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  await app.main();
  final controller = LiveWidgetController(WidgetsBinding.instance);
  final status = ValueNotifier('MD_HOTFIX_START');
  final captures = GlobalKey();
  final results = <String, Object?>{};
  final failures = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (error) {
    failures.add(error.exceptionAsString());
    original?.call(error);
  };
  final output = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/ios-hotfix',
  );
  await output.create(recursive: true);
  runApp(RepaintBoundary(key: captures, child: const app.MyApp()));
  Future<void> waitFor(bool Function() ready, String label) async {
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (!ready() && DateTime.now().isBefore(deadline)) {
      await controller.pump(const Duration(milliseconds: 200));
    }
    if (!ready()) throw StateError('Timeout: $label');
  }

  Future<void> capture(String name) async {
    await controller.pump(const Duration(milliseconds: 500));
    final boundary =
        captures.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
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
    Get.key.currentState!.overlay!.insert(
      OverlayEntry(
        builder: (_) => Positioned(
          bottom: 8,
          left: 8,
          child: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, value, _) => Text(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ),
      ),
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final response = await dio.get(
      'https://passport.bilibili.com/x/passport-login/captcha?source=main_web',
    );
    final captcha = response.data['data']['geetest'] as Map;
    dio.close();
    status.value = 'MD_CAPTCHA_RUNNING';
    // Display the real challenge, then cancel. Never automate solving it or SMS.
    final timer = Timer(const Duration(seconds: 30), () {
      const MethodChannel('com.rseam07.newbili/captcha')
          .invokeMethod<void>('cancel');
    });
    final validated = await GeetestWebviewDialog.geetest(
      captcha['gt'],
      captcha['challenge'],
    );
    timer.cancel();
    results['captcha'] = validated == null
        ? 'returned after cancellation; inspect native screenshot'
        : 'provider returned verification result';
    status.value = 'MD_CAPTCHA_RETURNED';
    await controller.pump(const Duration(milliseconds: 700));

    await PiliScheme.routePush(Uri.parse('newbili-md://video/BV15Xhk6dEsH'));
    await waitFor(
      () => find.byType(UgcIntroPanel).evaluate().isNotEmpty,
      'video introduction',
    );
    await controller.pump(const Duration(seconds: 2));
    final actions = find.byType(ActionItem);
    await controller.ensureVisible(actions.first);
    await controller.pump(const Duration(milliseconds: 500));
    final compact = actions
        .evaluate()
        .where((e) => (e.widget as ActionItem).compact)
        .toList();
    if (compact.length != 4) {
      throw StateError('Expected four portrait actions, got ${compact.length}');
    }
    for (final element in compact) {
      final box = element.findRenderObject()! as RenderBox;
      if (box.size.width < 48 || box.size.height < 80) {
        throw StateError('Action too small: ${box.size}');
      }
    }
    await capture('01-video-actions');
    results['actions'] = 'four labeled controls, each at least 48 x 80 points';
    Get.until((route) => route.isFirst);
    await controller.pump(const Duration(milliseconds: 500));

    final dynamics = DynamicsController();
    Get.to(
      () => Scaffold(
        appBar: AppBar(title: const Text('动态入口检查')),
        body: SizedBox(
          width: 76,
          child: UpPanel(
            upData: FollowUpModel.fromUpList(null),
            dynamicsController: dynamics,
          ),
        ),
      ),
    );
    await controller.pump(const Duration(milliseconds: 700));
    if (find.byIcon(Icons.dynamic_feed_rounded).evaluate().isEmpty) {
      throw StateError('All dynamics icon missing');
    }
    await capture('02-dynamics-icon');
    results['dynamicsIcon'] = 'theme-aware Material icon rendered';
    Get.back();
    await controller.pump(const Duration(milliseconds: 500));

    const invitation =
        'https://www.bilibili.com/blackboard/era/4uNKuLdhsvPBAoe2.html?legacy_jump=staff&new_jump=staff&is_owner=0&wbType=common&aid=117308626310327';
    results['invitationTarget'] = resolveWebLink(Uri.parse(invitation))
        .toString();
    Get.to(() => const WebviewPage(url: invitation));
    status.value = 'MD_INVITATION_LOADING';
    await controller.pump(const Duration(seconds: 10));
    // WKWebView surfaces are captured by XCTest, not Flutter's RepaintBoundary.
    status.value = failures.isEmpty ? 'MD_HOTFIX_PASSED' : 'MD_HOTFIX_FAILED';
  } catch (error, stack) {
    failures.add('$error\n$stack');
    status.value = 'MD_HOTFIX_FAILED';
  } finally {
    results['errors'] = failures;
    results['status'] = failures.isEmpty ? 'passed' : 'failed';
    await File('${output.path}/report.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  }
}
