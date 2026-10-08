import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

enum MainType { sideBar, bottomNav, body }

class MainLayout
    extends SlottedMultiChildRenderObjectWidget<MainType, RenderBox> {
  const MainLayout({
    super.key,
    required this.sideBar,
    required this.bottomNav,
    required this.body,
    this.trailingSideBar = false,
  });

  final Widget? sideBar;
  final Widget? bottomNav;
  final Widget body;
  final bool trailingSideBar;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .sideBar => sideBar,
    .bottomNav => bottomNav,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<MainType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderMainLayout()..trailingSideBar = trailingSideBar;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant SlottedContainerRenderObjectMixin<MainType, RenderBox>
    renderObject,
  ) {
    (renderObject as _RenderMainLayout).trailingSideBar = trailingSideBar;
  }
}

class _RenderMainLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<MainType, RenderBox>,
        SlottedLayoutMixin {
  RenderBox? get sideBar => childForSlot(.sideBar);
  RenderBox? get bottomNav => childForSlot(.bottomNav);
  RenderBox get body => childForSlot(.body)!;
  bool _trailingSideBar = false;
  set trailingSideBar(bool value) {
    if (_trailingSideBar == value) return;
    _trailingSideBar = value;
    markNeedsLayout();
  }

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;

    final sideBar = this.sideBar;
    if (sideBar != null) {
      final sideBarWidth = ChildLayoutHelper.layoutChild(
        sideBar,
        BoxConstraints.tightFor(height: constraints.maxHeight),
      ).width;
      setOffset(
        sideBar,
        Offset(_trailingSideBar ? size.width - sideBarWidth : 0, 0),
      );

      bodyOffset = Offset(_trailingSideBar ? 0 : sideBarWidth, 0);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth - sideBarWidth,
        height: constraints.maxHeight,
      );
    } else {
      double bottomHeight = 0;
      final bottomNav = this.bottomNav;
      if (bottomNav != null) {
        final bottomNavSize = ChildLayoutHelper.layoutChild(
          bottomNav,
          constraints.loosen(),
        );
        bottomHeight = bottomNavSize.height;
        setOffset(
          bottomNav,
          Offset(
            (constraints.maxWidth - bottomNavSize.width) / 2,
            constraints.maxHeight - bottomNavSize.height,
          ),
        );
      }

      bodyOffset = .zero;
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: (constraints.maxHeight - bottomHeight).clamp(
          0.0,
          double.infinity,
        ),
      );
    }

    final body = this.body..layout(bodyConstraints);
    setOffset(body, bodyOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, getOffset(child) + offset);
      }
    }

    doPaint(sideBar);
    doPaint(body);
    doPaint(bottomNav);
  }
}
