import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:PiliPlus/common/layout/newbili_adaptive_window.dart';
import 'package:PiliPlus/common/layout/newbili_fold_layout.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/common/widgets/newbili_navigation_bar.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'Duo uses one edge column and fills book/tabletop regions without replacing playback',
    (tester) async {
      var size = const Size(951, 669);
      var edge = NewbiliControlEdge.trailing;
      var features = <DisplayFeature>[];
      var fullscreen = false;
      late StateSetter update;
      final player = GlobalKey();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return NewbiliWindowScope(
                info: NewbiliWindowInfo(
                  size: size,
                  phone: true,
                  regularWidth: true,
                  controlEdge: edge,
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: size,
                    displayFeatures: features,
                    padding: edge == NewbiliControlEdge.trailing
                        ? const EdgeInsets.only(right: 84)
                        : EdgeInsets.zero,
                  ),
                  child: TabletPlayerStage(
                    adaptToFoldable: true,
                    isFullScreen: fullscreen,
                    selectedPane: '评论',
                    onBack: () {},
                    onHome: () {},
                    playerBuilder: (_, _) => StatefulBuilder(
                      key: player,
                      builder: (_, _) => const Text('同一播放器'),
                    ),
                    details: const Text('简介'),
                    secondary: const Center(child: Text('可用的评论')),
                    transport: const Center(child: Text('触控播放区域')),
                    onSendDanmaku: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = player.currentState;
      expect(find.text('可用的评论').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byType(NewbiliEdgeSurface)).width, 84);
      Future<void> resize(
        Size next,
        NewbiliControlEdge nextEdge,
        List<DisplayFeature> nextFeatures, {
        bool fs = false,
      }) async {
        await tester.binding.setSurfaceSize(next);
        update(() {
          size = next;
          edge = nextEdge;
          features = nextFeatures;
          fullscreen = fs;
        });
        await tester.pumpAndSettle();
        expect(player.currentState, same(state));
        expect(find.text('可用的评论').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await resize(size, edge, const [
        DisplayFeature(
          bounds: Rect.fromLTWH(455.5, 0, 40, 669),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]);
      expect(
        tester.getRect(find.byKey(player)).bottom,
        closeTo(455.5 / (16 / 9), .1),
      );
      expect(tester.getRect(find.text('触控播放区域')).left, lessThan(455.5));
      await resize(size, edge, features, fs: true);
      expect(find.text('触控播放区域').hitTestable(), findsOneWidget);
      await resize(const Size(669, 951), NewbiliControlEdge.bottom, const []);
      final portraitPlayer = tester.getRect(find.byKey(player));
      expect(portraitPlayer.width, 669);
      expect(portraitPlayer.height, closeTo(669 / (16 / 9), .1));
      final tabletop = const [
        DisplayFeature(
          bounds: Rect.fromLTWH(0, 455.5, 669, 40),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      await resize(size, edge, tabletop);
      await resize(size, edge, tabletop, fs: true);
      expect(tester.getRect(find.byKey(player)).bottom, 455.5);
      expect(find.text('触控播放区域').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'short tabletop pane keeps comments usable and the send action in its header',
    (tester) async {
      const size = Size(890, 540);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: size),
            child: Scaffold(
              body: TabletPlayerStage(
                initialOpen: true,
                selectedPane: '评论',
                playerBuilder: (_, _) => const Text('保留的播放器'),
                details: const Text('简介内容'),
                secondary: const SingleChildScrollView(child: Text('评论内容可用')),
                transport: const Text('桌面播放控制'),
                onSendDanmaku: () => sent++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('观看布局'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<NewbiliPlayerArrangement>,
          '桌面观看',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('评论内容可用').hitTestable(), findsOneWidget);
      expect(find.text('发弹幕'), findsNothing);
      await tester.tap(find.byTooltip('发弹幕'));
      expect(sent, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'scene host retains navigation through a zero-sized display transfer',
    (tester) async {
      final page = GlobalKey();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(890, 626);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => NewbiliAdaptiveWindow(child: child!),
          home: StatefulBuilder(
            key: page,
            builder: (context, _) => Center(
              child: Text('${MediaQuery.sizeOf(context).width.round()}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = page.currentState;
      tester.view.physicalSize = Size.zero;
      await tester.pumpAndSettle();
      expect(page.currentState, same(state));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(466, 678);
      await tester.pumpAndSettle();
      expect(page.currentState, same(state));
      expect(find.text('466'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cover, inner, book, tabletop, fullscreen and Split View retain playback and comment scroll',
    (tester) async {
      var size = const Size(466, 678);
      var features = <DisplayFeature>[];
      var fullscreen = false;
      var regular = false;
      late StateSetter update;
      final player = GlobalKey();
      final comments = ScrollController();
      addTearDown(comments.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(Get.reset);
      var position = 36;
      var selected = '简介';
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        GetMaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: size, displayFeatures: features),
                child: NewbiliWindowScope(
                  info: NewbiliWindowInfo(
                    size: size,
                    phone: true,
                    regularWidth: regular,
                  ),
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: TabletPlayerStage(
                        compact: !NewbiliWindowScope.expanded(context),
                        isFullScreen: fullscreen,
                        selectedPane: selected,
                        onPaneChanged: (value) => selected = value,
                        playerBuilder: (_, _) => StatefulBuilder(
                          key: player,
                          builder: (context, repaint) => Center(
                            child: TextButton(
                              onPressed: () => repaint(() => position++),
                              child: Text('播放 $position'),
                            ),
                          ),
                        ),
                        details: const Center(child: Text('视频简介')),
                        secondary: ListView.builder(
                          controller: comments,
                          itemCount: 100,
                          itemExtent: 60,
                          itemBuilder: (_, i) => Text('评论 $i'),
                        ),
                        extraPane: const Center(child: Text('关注动态')),
                        transport: const Center(child: Text('下半屏播放操作')),
                        onSendDanmaku: () {},
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final playerState = player.currentState;
      await tester.tap(find.text('评论'));
      await tester.pumpAndSettle();
      expect(selected, '评论');
      await tester.timedDrag(
        find.text('评论 0'),
        const Offset(0, -220),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      final scrollOffset = comments.offset;
      expect(scrollOffset, greaterThan(0));

      Future<void> resize(
        Size next, {
        List<DisplayFeature> regions = const [],
        bool expanded = true,
        bool fs = false,
      }) async {
        await tester.binding.setSurfaceSize(next);
        update(() {
          size = next;
          features = regions;
          regular = expanded;
          fullscreen = fs;
        });
        await tester.pumpAndSettle();
        expect(player.currentState, same(playerState));
        expect(comments.offset, scrollOffset);
        expect(selected, '评论');
        expect(tester.takeException(), isNull);
      }

      await resize(const Size(890, 626));
      await resize(Size.zero);
      await resize(const Size(890, 626));
      await tester.tap(find.text('播放 36'));
      await tester.pump();
      expect(find.text('播放 37'), findsOneWidget);
      await resize(
        const Size(890, 626),
        regions: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(438, 0, 14, 626),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      expect(tester.getRect(find.byKey(player)).right, 438);
      await resize(
        const Size(626, 890),
        regions: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 438, 626, 14),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      expect(tester.getRect(find.byKey(player)).bottom, 438);
      expect(tester.getRect(find.text('下半屏播放操作')).top, greaterThan(452));
      await resize(const Size(626, 890), fs: true, regions: features);
      expect(tester.getRect(find.byKey(player)).bottom, 438);
      expect(find.text('下半屏播放操作').hitTestable(), findsOneWidget);
      await resize(const Size(445, 626), expanded: false);
      expect(find.text('评论').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('观看布局'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<NewbiliPlayerArrangement>,
          '桌面观看',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(player)).bottom, 313);
      expect(player.currentState, same(playerState));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'outer-edge navigation handles safe area, large type and both split positions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(466, 678));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var index = 0;
      var trailing = true;
      late StateSetter update;
      final page = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(
                    top: 40,
                    right: 52,
                    bottom: 20,
                  ),
                  textScaler: TextScaler.linear(1.8),
                ),
                child: MainLayout(
                  trailingSideBar: trailing,
                  bottomNav: null,
                  sideBar: NewbiliEdgeNavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: (value) =>
                        update(() => index = value),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home),
                        label: '首页',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.dynamic_feed),
                        label: '动态',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.search),
                        label: '搜索',
                      ),
                    ],
                  ),
                  body: StatefulBuilder(
                    key: page,
                    builder: (_, _) => const Center(child: Text('连续的页面')),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = page.currentState;
      expect(tester.getRect(find.byKey(page)).right, 394);
      await tester.tap(find.byKey(const ValueKey('edge-destination-2')));
      await tester.pumpAndSettle();
      expect(index, 2);
      update(() => trailing = false);
      await tester.pumpAndSettle();
      expect(page.currentState, same(state));
      expect(tester.getRect(find.byKey(page)).left, 72);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
