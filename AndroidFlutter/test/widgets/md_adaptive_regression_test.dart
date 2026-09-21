import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:PiliPlus/common/layout/newbili_fold_layout.dart';
import 'package:PiliPlus/common/widgets/newbili_destination_view.dart';
import 'package:PiliPlus/common/widgets/newbili_press_feedback.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test(
    'normal tablets retain 70/30, hinges are excluded in either posture',
    () {
      const size = Size(1280, 800);
      final regular = NewbiliFoldLayout.resolve(size, []);
      expect(regular.player.right, 896);
      final vertical = NewbiliFoldLayout.resolve(size, [
        const DisplayFeature(
          bounds: Rect.fromLTWH(625, 0, 30, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ]);
      expect(vertical.player.right, 625);
      expect(vertical.content.left, greaterThanOrEqualTo(655));
      final horizontal = NewbiliFoldLayout.resolve(size, [
        const DisplayFeature(
          bounds: Rect.fromLTWH(0, 390, 1280, 20),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]);
      expect(horizontal.player.bottom, 390);
      expect(horizontal.content.top, greaterThanOrEqualTo(410));
    },
  );

  testWidgets('fold posture changes preserve the mounted player state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = GlobalKey();
    Widget build(List<DisplayFeature> features) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(900, 900),
          displayFeatures: features,
        ),
        child: Scaffold(
          body: TabletPlayerStage(
            initialOpen: true,
            playerBuilder: (_, _) => StatefulBuilder(
              key: player,
              builder: (_, _) => const Text('live player'),
            ),
            details: const Text('details'),
            secondary: const Text('comments'),
            onSendDanmaku: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(build([]));
    final state = player.currentState;
    await tester.pumpWidget(
      build([
        const DisplayFeature(
          bounds: Rect.fromLTWH(0, 440, 900, 20),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(player.currentState, same(state));
    expect(tester.getRect(find.byKey(player)).bottom, lessThanOrEqualTo(440));
    expect(
      tester.getRect(find.byKey(const ValueKey('tablet-content-surface'))).top,
      greaterThanOrEqualTo(460),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('removing visited navigation entries does not index old pages', (
    tester,
  ) async {
    Widget build(int index, int count) => MaterialApp(
      home: Scaffold(
        body: NewbiliDestinationView(
          index: index,
          children: [
            for (var i = 0; i < count; i++) Center(child: Text('page $i')),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(2, 3));
    await tester.pumpWidget(build(0, 1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('page 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('press motion yields to scrolling and respects reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NewbiliPressFeedback(
              child: SizedBox(
                width: 180,
                height: 90,
                child: TextButton(onPressed: () {}, child: const Text('Press')),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Press')),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      .975,
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.cancel();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const NewbiliPressFeedback(child: Text('Reduced')),
        ),
      ),
    );
    final reduced = await tester.startGesture(
      tester.getCenter(find.text('Reduced')),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await reduced.cancel();
    await tester.pumpWidget(const SizedBox());
  });
}
