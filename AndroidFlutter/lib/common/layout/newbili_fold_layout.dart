import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum NewbiliPlayerArrangement { auto, sideBySide, tabletop }

/// Uses live window geometry, including separating hinges and half-open folds.
class NewbiliFoldLayout {
  const NewbiliFoldLayout({
    required this.player,
    required this.content,
    required this.ball,
    required this.folded,
    this.compact = false,
    this.tabletop = false,
    this.transport = Rect.zero,
  });
  final Rect player, content, ball;
  final bool folded;
  final bool compact;
  final bool tabletop;
  final Rect transport;

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
      if ((b.height >= size.height * .75 &&
              b.left >= 160 &&
              b.right <= size.width - 160) ||
          (b.width >= size.width * .75 &&
              b.top >= 120 &&
              b.bottom <= size.height - 160)) {
        return feature;
      }
    }
    return null;
  }

  factory NewbiliFoldLayout.resolve(
    Size size,
    List<DisplayFeature> features, {
    bool compact = false,
    NewbiliPlayerArrangement arrangement = NewbiliPlayerArrangement.auto,
    double videoAspectRatio = 16 / 9,
    bool hasTransport = false,
  }) {
    // Zero-sized windows occur briefly during display/scene transitions.
    if (size.isEmpty) {
      return const NewbiliFoldLayout(
        player: Rect.zero,
        content: Rect.zero,
        ball: Rect.zero,
        folded: false,
        compact: true,
      );
    }
    final feature = separatingFeature(size, features);
    late final Rect player, pane;
    final horizontalFold =
        feature != null && feature.bounds.width >= size.width * .75;
    final tabletop =
        horizontalFold ||
        arrangement == NewbiliPlayerArrangement.tabletop &&
            feature == null &&
            size.height >= 360;
    final inline =
        !tabletop &&
        feature == null &&
        compact &&
        (arrangement != NewbiliPlayerArrangement.sideBySide ||
            size.width < 600);
    if (feature != null && !horizontalFold) {
      player = Rect.fromLTRB(0, 0, feature.bounds.left, size.height);
      pane = Rect.fromLTRB(feature.bounds.right, 0, size.width, size.height);
    } else if (tabletop) {
      final split = feature?.bounds.top ?? size.height * .5;
      player = Rect.fromLTRB(0, 0, size.width, split);
      pane = Rect.fromLTRB(
        0,
        feature?.bounds.bottom ?? split,
        size.width,
        size.height,
      );
    } else if (inline) {
      final available = math.max(
        0.0,
        size.height - math.min(180.0, size.height * .5),
      );
      final ratio = videoAspectRatio.isFinite && videoAspectRatio > 0
          ? videoAspectRatio
          : 16 / 9;
      final height = (size.width / ratio)
          .clamp(
            math.min(100.0, available),
            available,
          )
          .toDouble();
      player = Rect.fromLTWH(0, 0, size.width, height);
      pane = Rect.fromLTRB(0, height, size.width, size.height);
    } else {
      final extent = math.min(
        size.width * .48,
        math.max(280.0, size.width * .3),
      );
      player = Rect.fromLTWH(0, 0, size.width - extent, size.height);
      pane = Rect.fromLTWH(player.right, 0, extent, size.height);
    }
    final gutter = inline
        ? 0.0
        : math.min(12.0, math.min(pane.width, pane.height) / 12);
    final transportHeight = tabletop && hasTransport
        ? math.min(80.0, pane.height * .4)
        : 0.0;
    final content = Rect.fromLTRB(
      pane.left,
      pane.top + transportHeight,
      pane.right,
      pane.bottom,
    ).deflate(gutter);
    final diameter = math.min(56.0, math.min(content.width, content.height));
    final ball = Rect.fromLTWH(
      content.right - diameter - math.min(8, content.width - diameter),
      (tabletop
              ? content.bottom - diameter - 8
              : content.center.dy - diameter / 2)
          .clamp(content.top, content.bottom - diameter),
      diameter,
      diameter,
    );
    return NewbiliFoldLayout(
      player: player,
      content: content,
      ball: ball,
      folded: feature != null,
      compact: inline,
      tabletop: tabletop,
      transport: Rect.fromLTWH(
        pane.left,
        pane.top,
        pane.width,
        transportHeight,
      ),
    );
  }
}

/// MediaQuery must follow the actual pane, including keyboard intersection and
/// reserved regions. Global coordinates are never passed into a child pane.
class NewbiliSubRegion extends StatelessWidget {
  const NewbiliSubRegion({
    super.key,
    required this.bounds,
    required this.child,
  });
  final Rect bounds;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardTop = media.size.height - media.viewInsets.bottom;
    return MediaQuery(
      data: media.copyWith(
        size: bounds.size,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.only(
          bottom: (bounds.bottom - keyboardTop).clamp(0.0, bounds.height),
        ),
        displayFeatures: [
          for (final f in media.displayFeatures)
            if (f.bounds.overlaps(bounds))
              DisplayFeature(
                bounds: f.bounds.intersect(bounds).shift(-bounds.topLeft),
                type: f.type,
                state: f.state,
              ),
        ],
      ),
      child: child,
    );
  }
}
