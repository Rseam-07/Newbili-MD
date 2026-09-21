import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Uses live window geometry, including separating hinges and half-open folds.
class NewbiliFoldLayout {
  const NewbiliFoldLayout({
    required this.player,
    required this.content,
    required this.ball,
    required this.folded,
  });
  final Rect player, content, ball;
  final bool folded;

  static DisplayFeature? separatingFeature(
    Size size,
    List<DisplayFeature> features,
  ) {
    for (final feature in features) {
      final b = feature.bounds;
      final separates =
          feature.type == DisplayFeatureType.hinge ||
          feature.state == DisplayFeatureState.postureHalfOpened;
      if (!separates) continue;
      if ((b.height >= size.height * .8 &&
              b.left > 160 &&
              b.right < size.width - 160) ||
          (b.width >= size.width * .8 &&
              b.top > 140 &&
              b.bottom < size.height - 180)) {
        return feature;
      }
    }
    return null;
  }

  factory NewbiliFoldLayout.resolve(Size size, List<DisplayFeature> features) {
    final feature = separatingFeature(size, features);
    late final Rect player, pane;
    if (feature != null && feature.bounds.height >= size.height * .8) {
      player = Rect.fromLTRB(0, 0, feature.bounds.left, size.height);
      pane = Rect.fromLTRB(feature.bounds.right, 0, size.width, size.height);
    } else if (feature != null) {
      player = Rect.fromLTRB(0, 0, size.width, feature.bounds.top);
      pane = Rect.fromLTRB(0, feature.bounds.bottom, size.width, size.height);
    } else {
      final extent = math.min(
        size.width * .48,
        math.max(280.0, size.width * .3),
      );
      player = Rect.fromLTWH(0, 0, size.width - extent, size.height);
      pane = Rect.fromLTWH(player.right, 0, extent, size.height);
    }
    final gutter = math.min(12.0, math.min(pane.width, pane.height) / 12);
    return NewbiliFoldLayout(
      player: player,
      content: pane.deflate(gutter),
      ball: Rect.fromLTWH(pane.right - 76, pane.center.dy - 28, 56, 56),
      folded: feature != null,
    );
  }
}
