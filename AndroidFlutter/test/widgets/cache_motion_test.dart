import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/newbili_press_feedback.dart';
import 'package:PiliPlus/pages/setting/cache_page.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const output = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
  const font = String.fromEnvironment('NEWBILI_VISUAL_FONT');
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in fonts) {
      final loader = FontLoader(entry['family'] as String);
      for (final asset in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    if (font.isNotEmpty) {
      await ui.loadFontFromList(
        await File(font).readAsBytes(),
        fontFamily: 'Preview',
      );
    }
  });

  for (final (name, size, brightness, scale, reduced) in [
    ('cache-light', const Size(375, 812), Brightness.light, 1.0, false),
    ('cache-dark', const Size(375, 812), Brightness.dark, 1.0, false),
    ('cache-large-text', const Size(375, 812), Brightness.light, 3.0, true),
    ('cache-tablet', const Size(1024, 768), Brightness.dark, 1.0, false),
  ]) {
    testWidgets('$name layout and reduced motion', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: font.isEmpty ? null : 'Preview',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFB93A70),
                brightness: brightness,
              ),
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
              ),
              child: CacheSettingsPage(
                initialLimit: 256 << 20,
                loadUsage: () async =>
                    const CacheUsage(images: 96 << 20, temporary: 8 << 20),
                clearCache: () async {},
                updateLimit: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('104.0 MB'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      if (output.isNotEmpty) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          await Directory(output).create(recursive: true);
          await File('$output/$name.png').writeAsBytes(bytes);
          image.dispose();
        });
      }
    });
  }

  testWidgets(
    'clear runs once, reports failures and survives leaving the page',
    (tester) async {
      var clearCalls = 0;
      final completing = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: CacheSettingsPage(
            initialLimit: 256 << 20,
            loadUsage: () async => const CacheUsage(images: 1024, temporary: 0),
            clearCache: () {
              clearCalls++;
              return completing.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('清理缓存');
    await tester.scrollUntilVisible(button, 180, scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(clearCalls, 1);
      completing.completeError(const FileSystemException('full'));
      await tester.pumpAndSettle();
      expect(find.text('未能完成，请检查可用空间后重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final pending = Completer<CacheUsage>();
      await tester.pumpWidget(
        MaterialApp(
          home: CacheSettingsPage(
            key: UniqueKey(),
            initialLimit: 256 << 20,
            loadUsage: () => pending.future,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete(const CacheUsage(images: 0, temporary: 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'press reverses in place, scroll cancels, reduced motion stops ticking',
    (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: reduced,
            builder: (context, value, _) => MediaQuery(
              data: MediaQueryData(disableAnimations: value),
              child: Center(
                child: NewbiliPressFeedback(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      double scale() => tester
          .widget<ScaleTransition>(find.byType(ScaleTransition).first)
          .scale
          .value;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Open')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 55));
      final pressed = scale();
      expect(pressed, lessThan(1));
      await gesture.up();
      expect(scale(), pressed);
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 35));
      final second = await tester.startGesture(
        tester.getCenter(find.text('Open')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await second.moveBy(const Offset(0, 30));
      await tester.pumpAndSettle();
      expect(scale(), closeTo(1, .002));
      await second.cancel();
      reduced.value = true;
      await tester.pump();
      final third = await tester.startGesture(
        tester.getCenter(find.text('Open')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(scale(), 1);
      await third.up();
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
