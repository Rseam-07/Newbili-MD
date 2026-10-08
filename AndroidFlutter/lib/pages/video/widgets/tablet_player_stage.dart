import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/layout/newbili_fold_layout.dart';
import 'package:PiliPlus/common/layout/newbili_player_posture.dart';

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

/// One surface grows from its circular entry into a right-hand content card.
/// The same animation pushes the live player into the remaining 70% of space.
class TabletPlayerStage extends StatefulWidget {
  const TabletPlayerStage({
    super.key,
    required this.playerBuilder,
    required this.details,
    this.secondary,
    this.extraPane,
    this.playlist,
    this.selectedPane,
    this.onPaneChanged,
    this.initialOpen = false,
    this.isFullScreen = false,
    this.onOpenChanged,
    required this.onSendDanmaku,
    this.sheetKey,
    this.compact = false,
    this.videoAspectRatio = 16 / 9,
    this.transport,
  });
  final Widget Function(double width, double height) playerBuilder;
  final Widget details;
  final Widget? secondary;
  final Widget? extraPane;
  final Widget? playlist;
  final String? selectedPane;
  final ValueChanged<String>? onPaneChanged;
  final bool initialOpen;
  final bool isFullScreen;
  final ValueChanged<bool>? onOpenChanged;
  final VoidCallback onSendDanmaku;
  final GlobalKey<MiniScaffoldState>? sheetKey;
  final bool compact;
  final double videoAspectRatio;
  final Widget? transport;
  @override
  State<TabletPlayerStage> createState() => _TabletPlayerStageState();
}

class _TabletPlayerStageState extends State<TabletPlayerStage>
    with TickerProviderStateMixin {
  late String _selected = widget.selectedPane ?? '简介';
  late bool _open = widget.initialOpen || widget.compact;
  late bool _visited = _open;
  late final _expansion = AnimationController(
    vsync: this,
    value: _open ? 1 : 0,
    duration: NewbiliMotion.container,
  );
  late TabController _tabs;
  NewbiliPlayerArrangement _arrangement = NewbiliPlayerArrangement.auto;
  bool _inline = false;
  Size _lastSize = const Size(320, 600);

  List<String> get _names => [
    '简介',
    if (widget.secondary != null) '评论',
    if (widget.extraPane != null) '动态',
    if (widget.playlist != null) '选集',
  ];

  @override
  void initState() {
    super.initState();
    _inline = widget.compact;
    _createTabs();
    if (widget.isFullScreen) _expansion.value = 0;
  }

  void _createTabs() {
    final names = _names;
    final index = names.indexOf(widget.selectedPane ?? _selected);
    _tabs = TabController(
      length: names.length,
      initialIndex: index < 0 ? 0 : index,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _tabs.offset.abs() > .001) return;
    final name = _names[_tabs.index];
    if (_selected == name) return;
    setState(() => _selected = name);
    widget.onPaneChanged?.call(name);
  }

  void _animateExpansion() {
    final target = _open && !widget.isFullScreen ? 1.0 : 0.0;
    if (NewbiliMotion.reduced(context)) {
      _expansion.value = target;
    } else {
      _expansion.animateTo(
        target,
        duration: target == 1 ? NewbiliMotion.container : NewbiliMotion.exit,
        curve: NewbiliMotion.emphasized,
      );
    }
  }

  @override
  void didUpdateWidget(TabletPlayerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNames = [
      '简介',
      if (oldWidget.secondary != null) '评论',
      if (oldWidget.extraPane != null) '动态',
      if (oldWidget.playlist != null) '选集',
    ];
    if (!listEquals(oldNames, _names)) {
      _tabs.removeListener(_onTabChanged);
      _tabs.dispose();
      _createTabs();
    } else if (widget.selectedPane != null) {
      final index = _names.indexOf(widget.selectedPane!);
      if (index >= 0 && index != _tabs.index) {
        _tabs.animateTo(
          index,
          duration: NewbiliMotion.duration(context, NewbiliMotion.container),
        );
      }
    }
    if (widget.compact &&
        !oldWidget.compact &&
        !MediaQuery.sizeOf(context).isEmpty) {
      _open = _visited = true;
      widget.onOpenChanged?.call(true);
    }
    if (oldWidget.isFullScreen != widget.isFullScreen ||
        oldWidget.compact != widget.compact) {
      _animateExpansion();
    }
  }

  void _toggle() {
    if (_inline) return;
    setState(() {
      _open = !_open;
      _visited = true;
    });
    widget.onOpenChanged?.call(_open);
    _animateExpansion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NewbiliMotion.reduced(context)) {
      _expansion.value = _open && !widget.isFullScreen ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _expansion.dispose();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    _inline = NewbiliFoldLayout.resolve(
      MediaQuery.sizeOf(context),
      MediaQuery.of(context).displayFeatures,
      compact: widget.compact,
      arrangement: _arrangement,
    ).compact;
    final panes = <String, Widget>{
      '简介': widget.details,
      if (widget.secondary != null) '评论': widget.secondary!,
      if (widget.extraPane != null) '动态': widget.extraPane!,
      if (widget.playlist != null) '选集': widget.playlist!,
    };
    return PopScope(
      canPop: widget.isFullScreen || !_open || _inline,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_open || widget.isFullScreen || _inline) return;
        // Reply details use local history inside the card. Close that level
        // before collapsing the card or leaving the playing video.
        if (ModalRoute.of(context)?.willHandlePopInternally ?? false) {
          Navigator.of(context).pop();
        } else {
          _toggle();
        }
      },
      child: Material(
        color: widget.isFullScreen ? Colors.black : colors.surface,
        child: LayoutBuilder(
          builder: (context, box) {
            // Scene transfers can briefly report zero bounds. Lay out the same
            // retained children at the previous size, clipped by the empty view.
            final empty = box.biggest.isEmpty;
            if (!empty) _lastSize = box.biggest;
            final size = _lastSize;
            final layout = NewbiliFoldLayout.resolve(
              size,
              MediaQuery.of(context).displayFeatures,
              compact: widget.compact,
              arrangement: _arrangement,
              videoAspectRatio: widget.videoAspectRatio,
              hasTransport: widget.transport != null,
            );
            _inline = layout.compact;
            final card = layout.content;
            final ball = layout.ball;
            return OverflowBox(
              minWidth: size.width,
              maxWidth: size.width,
              minHeight: size.height,
              maxHeight: size.height,
              child: IgnorePointer(
                ignoring: empty,
                child: AnimatedBuilder(
                  animation: _expansion,
                  builder: (context, _) {
                    final t = _expansion.value;
                    final bounds = Rect.lerp(ball, card, t)!;
                    final contentOpacity = ((t - .25) / .75).clamp(0.0, 1.0);
                    final geometryDuration = _expansion.isAnimating
                        ? Duration.zero
                        : NewbiliMotion.duration(
                            context,
                            NewbiliMotion.container,
                          );
                    final playerBounds = Rect.lerp(
                      layout.folded ||
                              layout.tabletop ||
                              layout.compact && !widget.isFullScreen
                          ? layout.player
                          : Offset.zero & size,
                      layout.player,
                      t,
                    )!;
                    return Stack(
                      children: [
                        AnimatedPositioned.fromRect(
                          duration: geometryDuration,
                          curve: NewbiliMotion.emphasized,
                          // A single player element survives animation and folding.
                          rect: playerBounds,
                          child: NewbiliPlayerPosture(
                            tabletop: layout.tabletop,
                            child: ColoredBox(
                              color: Colors.black,
                              child: LayoutBuilder(
                                builder: (context, playerBox) =>
                                    widget.playerBuilder(
                                      playerBox.maxWidth,
                                      playerBox.maxHeight,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned.fromRect(
                          duration: geometryDuration,
                          curve: NewbiliMotion.emphasized,
                          rect: bounds,
                          child: Offstage(
                            offstage: widget.isFullScreen && t == 0,
                            child: IgnorePointer(
                              ignoring: widget.isFullScreen,
                              child: Material(
                                key: const ValueKey('tablet-content-surface'),
                                color: Color.lerp(
                                  colors.secondaryContainer,
                                  colors.surfaceContainerLow,
                                  t,
                                ),
                                elevation: lerpDouble(4, 1, t)!,
                                shadowColor: colors.shadow.withValues(
                                  alpha: .24,
                                ),
                                borderRadius: BorderRadius.circular(
                                  layout.compact ? 0 : lerpDouble(28, 20, t)!,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_visited)
                                      IgnorePointer(
                                        ignoring: !_open || t < .99,
                                        child: ExcludeSemantics(
                                          excluding: !_open || t < .99,
                                          child: Opacity(
                                            opacity: contentOpacity,
                                            child: OverflowBox(
                                              alignment: Alignment.topRight,
                                              minWidth: card.width,
                                              maxWidth: card.width,
                                              minHeight: card.height,
                                              maxHeight: card.height,
                                              child: NewbiliSubRegion(
                                                bounds: card,
                                                child: ExcludeFocus(
                                                  excluding: !_open,
                                                  child: TickerMode(
                                                    enabled:
                                                        _open &&
                                                        !widget.isFullScreen,
                                                    child: MiniScaffold(
                                                      key: widget.sheetKey,
                                                      body: Builder(
                                                        builder: (context) =>
                                                            _cardContent(
                                                              context,
                                                              panes,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (t < .35)
                                      IgnorePointer(
                                        ignoring: _open,
                                        child: ExcludeSemantics(
                                          excluding: _open,
                                          child: Opacity(
                                            opacity: (1 - t / .35).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child: Tooltip(
                                              message: '打开简介、评论与动态',
                                              child: InkWell(
                                                onTap: _toggle,
                                                child: Icon(
                                                  Icons.forum_outlined,
                                                  size: 26,
                                                  color: colors
                                                      .onSecondaryContainer,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (layout.tabletop && widget.transport != null)
                          Positioned.fromRect(
                            rect: layout.transport,
                            child: Material(
                              color: colors.surfaceContainer,
                              child: NewbiliSubRegion(
                                bounds: layout.transport,
                                child: widget.transport!,
                              ),
                            ),
                          ),
                        // A manual posture choice also works on hosts whose SDK
                        // has not yet exposed reserved regions (including iOS 27.0).
                        if (!widget.isFullScreen)
                          Positioned(
                            left: (playerBounds.right - 56).clamp(
                              playerBounds.left,
                              size.width - 48,
                            ),
                            top: playerBounds.top + 8,
                            child: Material(
                              color: colors.surfaceContainer.withValues(
                                alpha: .94,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              child: PopupMenuButton<NewbiliPlayerArrangement>(
                                tooltip: '观看布局',
                                icon: const Icon(
                                  Icons.devices_fold_rounded,
                                  size: 22,
                                ),
                                initialValue: _arrangement,
                                onSelected: (value) =>
                                    setState(() => _arrangement = value),
                                itemBuilder: (_) => [
                                  for (final (value, label) in const [
                                    (NewbiliPlayerArrangement.auto, '自动适应'),
                                    (
                                      NewbiliPlayerArrangement.sideBySide,
                                      '并排观看',
                                    ),
                                    (NewbiliPlayerArrangement.tabletop, '桌面观看'),
                                  ])
                                    CheckedPopupMenuItem(
                                      value: value,
                                      checked: _arrangement == value,
                                      child: Text(label),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cardContent(
    BuildContext context,
    Map<String, Widget> panes,
  ) {
    final colors = ColorScheme.of(context);
    final names = panes.keys.toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerHeight: 0,
                labelColor: colors.primary,
                unselectedLabelColor: colors.onSurfaceVariant,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [for (final name in names) Tab(height: 52, text: name)],
              ),
            ),
            if (!_inline)
              IconButton(
                tooltip: '收起内容卡片',
                onPressed: _toggle,
                icon: const Icon(Icons.close_rounded),
              ),
            if (MediaQuery.sizeOf(context).height < 180)
              IconButton(
                tooltip: '发弹幕',
                onPressed: widget.onSendDanmaku,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final entry in panes.entries)
                KeepAliveWrapper(key: ValueKey(entry.key), child: entry.value),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).height >= 180)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: widget.onSendDanmaku,
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('发弹幕'),
              ),
            ),
          ),
      ],
    );
  }
}
