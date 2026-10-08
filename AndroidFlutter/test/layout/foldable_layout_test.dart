import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:PiliPlus/common/layout/newbili_adaptive_window.dart';
import 'package:PiliPlus/common/layout/newbili_fold_layout.dart';
import 'package:PiliPlus/common/layout/newbili_fold_grid.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

DisplayFeature fold(Rect bounds, {bool flat = false}) => DisplayFeature(
  bounds: bounds,
  type: DisplayFeatureType.fold,
  state: flat
      ? DisplayFeatureState.postureFlat
      : DisplayFeatureState.postureHalfOpened,
);

void main() {
  test('cover, split window and expanded layouts keep usable bounds', () {
    for (final size in const [
      Size(466, 678),
      Size(320, 360),
      Size(890, 626),
      Size(626, 890),
      Size.zero,
    ]) {
      final layout = NewbiliFoldLayout.resolve(
        size,
        const [],
        compact: size.width < 600,
      );
      for (final r in [layout.player, layout.content, layout.ball]) {
        expect(r.width, greaterThanOrEqualTo(0));
        expect(r.height, greaterThanOrEqualTo(0));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
        expect(r.bottom, lessThanOrEqualTo(size.height));
      }
    }
  });

  test(
    'book and tabletop respect active reserved regions and transport space',
    () {
      final book = NewbiliFoldLayout.resolve(const Size(890, 626), [
        fold(const Rect.fromLTWH(438, 0, 14, 626)),
      ]);
      expect(book.player.right, 438);
      expect(book.content.left, greaterThanOrEqualTo(452));
      expect(book.tabletop, isFalse);
      final table = NewbiliFoldLayout.resolve(const Size(626, 890), [
        fold(const Rect.fromLTWH(0, 438, 626, 14)),
      ], hasTransport: true);
      expect(table.player.bottom, 438);
      expect(table.transport.top, 452);
      expect(table.content.top, greaterThan(table.transport.bottom));
      expect(table.ball.overlaps(table.player), isFalse);
      expect(table.tabletop, isTrue);
    },
  );

  test('flat creases and cutouts do not force a split; manual tabletop is independent', () {
    final features = [
      fold(const Rect.fromLTWH(445, 0, 0, 626), flat: true),
      const DisplayFeature(
        bounds: Rect.fromLTWH(700, 8, 48, 24),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ];
    expect(
      NewbiliFoldLayout.resolve(const Size(890, 626), features).folded,
      isFalse,
    );
    final manual = NewbiliFoldLayout.resolve(
      const Size(466, 678),
      const [],
      compact: true,
      arrangement: NewbiliPlayerArrangement.tabletop,
      hasTransport: true,
    );
    expect(manual.tabletop, isTrue);
    expect(manual.player.bottom, 339);
    expect(manual.transport.bottom, lessThan(manual.content.bottom));
    final physicalHinge = const DisplayFeature(
      bounds: Rect.fromLTWH(438, 0, 14, 626),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    );
    expect(
      NewbiliFoldLayout.resolve(const Size(890, 626), [physicalHinge]).folded,
      isTrue,
    );
  });

  test('scene snapshot rejects stale geometry even when displays have the same aspect', () {
    final info = NewbiliWindowInfo.fromMap({
      'width': 890,
      'height': 626,
      'regularWidth': true,
      'phone': true,
      'controlEdge': 'leading',
      'nativeFoldApi': true,
      'regions': [
        {
          'kind': 'division',
          'active': true,
          'x': 438,
          'y': 0,
          'width': 14,
          'height': 626,
        },
      ],
    });
    expect(info.controlEdge, NewbiliControlEdge.leading);
    expect(
      info.featuresFor(const Size(890, 626)).single.state,
      DisplayFeatureState.postureHalfOpened,
    );
    expect(info.featuresFor(const Size(445, 313)), isEmpty);
    expect(info.featuresFor(const Size(626, 890)), isEmpty);
  });

  test('lazy feed cards avoid both sides of the hinge, including RTL and final row', () {
    for (final rtl in [false, true]) {
      final delegate = NewbiliFoldGridDelegate(
        base: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
        ),
        hinge: const Rect.fromLTWH(410, 0, 22, 626),
        maxExtent: 240,
        spacing: 12,
        rowSpacing: 20,
        aspectRatio: 16 / 9,
        metadataHeight: 96,
      );
      final layout = delegate.getLayout(
        SliverConstraints(
          axisDirection: AxisDirection.down,
          growthDirection: GrowthDirection.forward,
          userScrollDirection: ScrollDirection.idle,
          scrollOffset: 0,
          precedingScrollExtent: 0,
          overlap: 0,
          remainingPaintExtent: 626,
          crossAxisExtent: 842,
          crossAxisDirection: rtl ? AxisDirection.left : AxisDirection.right,
          viewportMainAxisExtent: 626,
          remainingCacheExtent: 626,
          cacheOrigin: 0,
        ),
      );
      for (var i = 0; i < 9; i++) {
        final geometry = layout.getGeometryForChildIndex(i);
        final r = Rect.fromLTWH(
          geometry.crossAxisOffset,
          geometry.scrollOffset,
          geometry.crossAxisExtent,
          geometry.mainAxisExtent,
        );
        expect(r.overlaps(const Rect.fromLTWH(410, 0, 22, 10000)), isFalse);
        expect(r.right, lessThanOrEqualTo(842));
      }
      expect(layout.computeMaxScrollOffset(0), 0);
      final last = layout.getGeometryForChildIndex(8);
      expect(
        layout.computeMaxScrollOffset(9),
        last.scrollOffset + last.mainAxisExtent,
      );
    }
  });
}
