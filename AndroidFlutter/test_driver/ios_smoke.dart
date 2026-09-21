// Runs inside the simulator with the real app binding and native plugins.
// This entry point is never included in the distributed application.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/main.dart' as app;
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/common/widgets/svg/play_icon.dart';
import 'package:PiliPlus/pages/main/view.dart';
import 'package:PiliPlus/pages/search/view.dart';
import 'package:PiliPlus/pages/search_result/view.dart';
import 'package:PiliPlus/pages/video/view.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  final failures = <String>[];
  final results = <String, Object?>{};
  final captures = GlobalKey();
  await app.main();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    failures.add(details.exceptionAsString());
    previous?.call(details);
  };
  final controller = LiveWidgetController(WidgetsBinding.instance);
  final output = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/ios-smoke',
  );
  await output.create(recursive: true);
  runApp(RepaintBoundary(key: captures, child: const app.MyApp()));

  Future<void> waitFor(
    bool Function() ready,
    String description, {
    int seconds = 20,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (!ready() && DateTime.now().isBefore(deadline)) {
      await controller.pump(const Duration(milliseconds: 200));
    }
    if (!ready()) throw StateError('Timed out: $description');
  }

  Future<void> save(String name) async {
    await controller.pump(const Duration(milliseconds: 600));
    final boundary =
        captures.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${output.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    debugPrint('MD_SMOKE_CAPTURE:$name');
  }

  Future<Map<String, dynamic>> updates(
    String method, [
    Map<String, Object?>? args,
  ]) async => jsonDecode(
    (await const MethodChannel('com.rseam07.newbili/updates')
        .invokeMethod<String>(method, args))!,
  ) as Map<String, dynamic>;

  try {
    await controller.pump(const Duration(seconds: 1));
    const vault = MethodChannel('com.rseam07.newbili/legacy_account');
    final firstKey = await vault.invokeMethod<Uint8List>('accountHiveKey');
    final secondKey = await vault.invokeMethod<Uint8List>('accountHiveKey');
    if (firstKey?.length != 32 || !listEquals(firstKey, secondKey)) {
      throw StateError('Keychain encryption key is not stable');
    }
    results['keychain'] = 'stable 256-bit key; encrypted Hive opened';
    results['deviceSize'] = DeviceUtils.size.toString();
    final skip = find.byKey(const ValueKey('onboarding-skip'));
    if (skip.evaluate().isNotEmpty) {
      await save('01-onboarding');
      await controller.tap(find.byKey(const ValueKey('onboarding-next')));
      await controller.pump(const Duration(milliseconds: 500));
      await controller.tap(skip);
    }
    await waitFor(() => find.byType(MainApp).evaluate().isNotEmpty, 'home');
    results['onboarding'] = GStorage.setting.get(
      SettingBoxKey.newbiliOnboardingVersion,
    );
    if (const bool.fromEnvironment('MD_SMOKE_EDGE_ONLY')) {
      Get.toNamed('/search');
      await waitFor(
        () => find.byType(SearchPage).evaluate().isNotEmpty,
        'search',
      );
      await controller.pump(const Duration(milliseconds: 600));
      final window = DeviceUtils.size;
      final gesture = await controller.startGesture(
        Offset(4, window.height * .55),
      );
      await gesture.moveBy(Offset(window.width * .3, 0));
      await controller.pump(const Duration(milliseconds: 100));
      if (!Get.key.currentState!.userGestureInProgress) {
        throw StateError('iOS interactive back did not start');
      }
      await gesture.moveBy(Offset(window.width * .5, 0));
      await gesture.up();
      await waitFor(
        () => find.byType(SearchPage).evaluate().isEmpty,
        'edge back',
      );
      results['edgeBack'] = 'interactive drag began and returned to home';
      await save('07-edge-back');
      return;
    }
    await waitFor(
      () => find.byType(VideoCardV).evaluate().isNotEmpty,
      'online recommendations',
    );
    await save('02-home');
    final card = controller.widget<VideoCardV>(find.byType(VideoCardV).first);
    final bvid = card.videoItem.bvid;
    if (bvid == null) throw StateError('Recommendation has no BVID');
    results['recommendations'] = 'real API cards loaded';

    Get.toNamed('/search');
    await waitFor(
      () => find.byType(SearchPage).evaluate().isNotEmpty,
      'search',
    );
    final input = controller.widget<TextField>(find.byType(TextField).first);
    input.controller!.text = 'Blender Spring';
    input.onSubmitted!('Blender Spring');
    await waitFor(
      () => find.byType(SearchResultPage).evaluate().isNotEmpty,
      'search results',
    );
    await controller.pump(const Duration(seconds: 2));
    await save('03-search');
    results['search'] = 'submitted search and opened result page';
    Get.until((route) => route.isFirst);
    await controller.pump(const Duration(milliseconds: 600));
    final routed = await PiliScheme.routePush(
      Uri.parse('newbili-md://video/$bvid'),
    );
    if (!routed) throw StateError('MD deep link rejected');
    await waitFor(
      () => find.byType(VideoDetailPageV).evaluate().isNotEmpty,
      'video detail',
    );
    await controller.pump(const Duration(seconds: 2));
    // Autoplay is off on first launch; tap the cover's actual play affordance.
    await controller.tap(find.byType(PlayIcon).first);
    await waitFor(
      () =>
          (PlPlayerController
                  .instance
                  ?.videoPlayerController
                  ?.state
                  .position
                  .inMilliseconds ??
              0) >
          1200,
      'native video position advances',
      seconds: 30,
    );
    final player = PlPlayerController.instance!;
    results['video'] = {
      'bvid': bvid,
      'positionMs': player.videoPlayerController!.state.position.inMilliseconds,
      'durationMs': player.videoPlayerController!.state.duration.inMilliseconds,
    };
    await save('04-player');
    final panel = find.byTooltip('打开简介、评论与动态');
    if (panel.evaluate().isNotEmpty) {
      await controller.tap(panel);
      await controller.pump(const Duration(milliseconds: 500));
      final comments = find.descendant(
        of: find.byType(TabletPlayerStage),
        matching: find.text('评论'),
      );
      await controller.tap(comments.first);
      await controller.pump(const Duration(seconds: 2));
      await save('05-comments');
      await controller.tap(find.byTooltip('收起内容卡片'));
      results['tabletPanel'] =
          'opened comments and collapsed without restarting player';
    }
    await player.videoPlayerController!.pause();
    final position = player.videoPlayerController!.state.position;
    await controller.pump(const Duration(milliseconds: 500));
    if ((player.videoPlayerController!.state.position - position).inMilliseconds
            .abs() >
        500) {
      throw StateError('Pause did not stop playback');
    }
    await player.videoPlayerController!.play();
    await controller.pump(const Duration(milliseconds: 800));
    results['pauseResume'] = 'passed';
    final window = DeviceUtils.size;
    await controller.timedDragFrom(
      Offset(4, window.height * .55),
      Offset(window.width * .8, 0),
      const Duration(milliseconds: 450),
    );
    await waitFor(
      () => find.byType(VideoDetailPageV).evaluate().isEmpty,
      'interactive edge back',
    );
    results['edgeBack'] = 'completed interactive iOS back gesture';
    await waitFor(
      () => find.byType(MainApp).evaluate().isNotEmpty,
      'return to home',
    );
    await save('06-return-home');

    final snapshot = jsonEncode({
      'bvid': bvid,
      'title': 'Simulator regression',
      'pages': [
        {'cid': 1, 'page': 1, 'part': 'baseline'},
      ],
    });
    await updates('mark', {'video': snapshot});
    final oldCheck = updates('check', {
      'manual': true,
    }).catchError((Object _) => <String, dynamic>{});
    await updates('unmark', {'bvid': bvid});
    final clean = await updates('check', {'manual': true});
    await oldCheck;
    if ((clean['tracks'] as List).isNotEmpty || clean['checking'] != false) {
      throw StateError('Cancelled update check restored an obsolete track');
    }
    results['nativeUpdates'] =
        'mark, concurrent check, unmark, replacement check passed';
  } catch (error, stack) {
    failures.add('$error');
    debugPrint('MD_SMOKE_FAILURE:$error\n$stack');
    await save('failure');
  } finally {
    results['frameworkErrors'] = failures;
    results['passed'] = failures.isEmpty;
    results['completedAt'] = DateTime.now().toUtc().toIso8601String();
    await File('${output.path}/report.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    debugPrint('MD_SMOKE_DONE:${failures.isEmpty}:${output.path}');
    final context = Get.overlayContext;
    if (context != null && context.mounted) {
      Overlay.of(context).insert(
        OverlayEntry(
          builder: (_) => Positioned(
            left: 16,
            top: 50,
            child: Semantics(
              label: failures.isEmpty ? 'MD_SMOKE_PASSED' : 'MD_SMOKE_FAILED',
              child: const SizedBox(width: 2, height: 2),
            ),
          ),
        ),
      );
    }
  }
}
