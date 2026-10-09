import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Lazy grid rows continue across both panels. Each cover and its tap target
/// stays wholly on one side of a vertical fold, without duplicating the feed.
class NewbiliFoldGridDelegate extends SliverGridDelegate {
  const NewbiliFoldGridDelegate({
    required this.base,
    required this.hinge,
    required this.maxExtent,
    required this.spacing,
    required this.rowSpacing,
    required this.aspectRatio,
    required this.metadataHeight,
    this.evenColumns = false,
  });
  final SliverGridDelegate base;
  final Rect? hinge;
  final double maxExtent, spacing, rowSpacing, aspectRatio, metadataHeight;
  final bool evenColumns;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final fold = hinge;
    final width = constraints.crossAxisExtent;
    if (fold == null || fold.left < 140 || fold.right > width - 140) {
      if (evenColumns && width >= 560) {
        final preferred = math.max(2, (width / (maxExtent + spacing)).ceil());
        final count = preferred.isEven ? preferred : preferred + 1;
        final tile = (width - (count - 1) * spacing) / count;
        return SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          crossAxisSpacing: spacing,
          mainAxisSpacing: rowSpacing,
          mainAxisExtent: tile / aspectRatio + metadataHeight,
        ).getLayout(constraints);
      }
      return base.getLayout(constraints);
    }
    final leftWidth = fold.left - spacing;
    final rightWidth = width - fold.right - spacing;
    final leftCount = math.max(1, (leftWidth / (maxExtent + spacing)).ceil());
    final rightCount = math.max(1, (rightWidth / (maxExtent + spacing)).ceil());
    final leftTile = (leftWidth - (leftCount - 1) * spacing) / leftCount;
    final rightTile = (rightWidth - (rightCount - 1) * spacing) / rightCount;
    return _FoldGridLayout(
      leftCount: leftCount,
      rightCount: rightCount,
      leftTile: leftTile,
      rightTile: rightTile,
      tileHeight: math.max(leftTile, rightTile) / aspectRatio + metadataHeight,
      spacing: spacing,
      rowSpacing: rowSpacing,
      rightStart: fold.right + spacing,
      width: width,
      reverse: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(NewbiliFoldGridDelegate oldDelegate) =>
      hinge != oldDelegate.hinge ||
      evenColumns != oldDelegate.evenColumns ||
      maxExtent != oldDelegate.maxExtent ||
      spacing != oldDelegate.spacing ||
      rowSpacing != oldDelegate.rowSpacing ||
      aspectRatio != oldDelegate.aspectRatio ||
      metadataHeight != oldDelegate.metadataHeight ||
      base.shouldRelayout(oldDelegate.base);
}

class _FoldGridLayout extends SliverGridLayout {
  const _FoldGridLayout({
    required this.leftCount,
    required this.rightCount,
    required this.leftTile,
    required this.rightTile,
    required this.tileHeight,
    required this.spacing,
    required this.rowSpacing,
    required this.rightStart,
    required this.width,
    required this.reverse,
  });
  final int leftCount, rightCount;
  final double leftTile,
      rightTile,
      tileHeight,
      spacing,
      rowSpacing,
      rightStart,
      width;
  final bool reverse;
  int get count => leftCount + rightCount;
  double get stride => tileHeight + rowSpacing;
  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      count * math.max(0, (scrollOffset / stride).floor());
  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      math.max(0, count * (scrollOffset / stride).ceil() - 1);
  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final column = index % count;
    final tileWidth = column < leftCount ? leftTile : rightTile;
    final x = column < leftCount
        ? column * (tileWidth + spacing)
        : rightStart + (column - leftCount) * (tileWidth + spacing);
    return SliverGridGeometry(
      scrollOffset: (index ~/ count) * stride,
      crossAxisOffset: reverse ? width - x - tileWidth : x,
      mainAxisExtent: tileHeight,
      crossAxisExtent: tileWidth,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) => childCount == 0
      ? 0
      : ((childCount + count - 1) ~/ count) * stride - rowSpacing;
}
