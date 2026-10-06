import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'side tabs follow swipes and fullscreen keeps the player and pane state',
    (tester) async {
      const size = Size(1280, 800);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fullscreen = false;
      var selected = '简介';
      late StateSetter update;
      final surface = GlobalKey();
      final intro = GlobalKey();
      var position = 36;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return TabletPlayerStage(
                initialOpen: true,
                isFullScreen: fullscreen,
                selectedPane: selected,
                onPaneChanged: (name) => setState(() => selected = name),
                playerBuilder: (_, _) => StatefulBuilder(
                  key: surface,
                  builder: (_, setPlayerState) => Center(
                    child: TextButton(
                      onPressed: () => setPlayerState(() => position++),
                      child: Text('playing $position'),
                    ),
                  ),
                ),
                details: StatefulBuilder(
                  key: intro,
                  builder: (_, _) => const Center(child: Text('简介内容')),
                ),
                secondary: const Center(child: Text('评论内容')),
                extraPane: const Center(child: Text('动态内容')),
                onSendDanmaku: () {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final playerState = surface.currentState;
      final introState = intro.currentState;
      await tester.drag(find.text('简介内容'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(selected, '评论');
      expect(find.text('评论内容').hitTestable(), findsOneWidget);
      await tester.drag(find.text('评论内容'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(selected, '动态');
      await tester.drag(find.text('动态内容'), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(selected, '评论');
      update(() => fullscreen = true);
      await tester.pump(const Duration(milliseconds: 90));
      expect(surface.currentState, same(playerState));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(surface)), Offset.zero & size);
      expect(find.text('评论内容').hitTestable(), findsNothing);
      await tester.tap(find.text('playing 36'));
      await tester.pump();
      // Reverse partway through the transition, preserving the current surface.
      update(() => fullscreen = false);
      await tester.pump(const Duration(milliseconds: 60));
      update(() => fullscreen = true);
      await tester.pump(const Duration(milliseconds: 60));
      update(() => fullscreen = false);
      await tester.pumpAndSettle();
      expect(surface.currentState, same(playerState));
      expect(intro.currentState, same(introState));
      expect(find.text('playing 37'), findsOneWidget);
      expect(find.text('评论内容').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tablet reply details stay in the card and unwind before playback',
    (
      tester,
    ) async {
      const size = Size(1280, 800);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(Get.reset);
      final sheetKey = GlobalKey<MiniScaffoldState>();
      final playerKey = GlobalKey();
      var position = 36;

      Widget replyList(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => MiniScaffold.of(context).showBottomSheet(
            constraints: const BoxConstraints(),
            (context) => SizedBox.expand(
              key: const ValueKey('reply-details'),
              child: Material(
                child: Column(
                  children: [
                    const Text('评论详情'),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭详情'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          child: const Text('共4条回复'),
        ),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () => Get.to<void>(
                () => Scaffold(
                  body: TabletPlayerStage(
                    sheetKey: sheetKey,
                    playerBuilder: (_, _) => StatefulBuilder(
                      key: playerKey,
                      builder: (context, setState) => Center(
                        child: TextButton(
                          onPressed: () => setState(() => position++),
                          child: Text('播放位置 $position'),
                        ),
                      ),
                    ),
                    details: const Center(child: Text('视频简介')),
                    secondary: Builder(builder: replyList),
                    onSendDanmaku: () {},
                  ),
                ),
              ),
              child: const Text('打开视频'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开视频'));
      await tester.pumpAndSettle();
      final playerState = playerKey.currentState;
      expect(tester.getRect(find.byKey(playerKey)), Offset.zero & size);
      expect(find.text('Newbili'), findsNothing);

      await tester.tap(find.byTooltip('打开简介、评论与动态'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('评论'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('共4条回复'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('评论详情').hitTestable(), findsOneWidget);
      final card = tester.getRect(
        find.byKey(const ValueKey('tablet-content-surface')),
      );
      expect(tester.getRect(find.byKey(const ValueKey('reply-details'))), card);
      expect(tester.getRect(find.byKey(playerKey)).right, size.width * .7);
      expect(playerKey.currentState, same(playerState));
      expect(sheetKey.currentState, isNotNull);

      // Reply details must not capture touches on the video.
      await tester.tap(find.text('播放位置 36'));
      await tester.pump();
      expect(find.text('播放位置 37'), findsOneWidget);
      await tester.tap(find.text('关闭详情'));
      await tester.pumpAndSettle();
      expect(find.text('评论详情'), findsNothing);
      expect(find.text('共4条回复').hitTestable(), findsOneWidget);

      await tester.tap(find.text('共4条回复'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('评论详情'), findsNothing);
      expect(find.text('共4条回复').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byTooltip('打开简介、评论与动态').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byKey(playerKey)), Offset.zero & size);
      expect(playerKey.currentState, same(playerState));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('打开视频'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
