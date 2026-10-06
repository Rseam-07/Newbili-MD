import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/layout/newbili_fold_layout.dart';

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
  @override
  State<TabletPlayerStage> createState() => _TabletPlayerStageState();
}

class _TabletPlayerStageState extends State<TabletPlayerStage>
    with TickerProviderStateMixin {
  late String _selected = widget.selectedPane ?? '简介';
  late bool _open = widget.initialOpen;
  late bool _visited = _open;
  late final _expansion = AnimationController(
    vsync: this,
    value: _open ? 1 : 0,
    duration: NewbiliMotion.container,
  );
  late TabController _tabs;

  List<String> get _names => [
    '简介',
    if (widget.secondary != null) '评论',
    if (widget.extraPane != null) '动态',
    if (widget.playlist != null) '选集',
  ];

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.isFullScreen != widget.isFullScreen) _animateExpansion();
  }

  void _toggle() {
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
    final panes = <String, Widget>{
      '简介': widget.details,
      if (widget.secondary != null) '评论': widget.secondary!,
      if (widget.extraPane != null) '动态': widget.extraPane!,
      if (widget.playlist != null) '选集': widget.playlist!,
    };
    return PopScope(
      canPop: widget.isFullScreen || !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_open || widget.isFullScreen) return;
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
            final layout = NewbiliFoldLayout.resolve(
              box.biggest,
              MediaQuery.of(context).displayFeatures,
            );
            final card = layout.content;
            final ball = layout.ball;
            return AnimatedBuilder(
              animation: _expansion,
              builder: (context, _) {
                final t = _expansion.value;
                final bounds = Rect.lerp(ball, card, t)!;
                final contentOpacity = ((t - .25) / .75).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Positioned.fromRect(
                      // A single player element survives animation and folding.
                      rect: Rect.lerp(
                        layout.folded && !widget.isFullScreen
                            ? layout.player
                            : Offset.zero & box.biggest,
                        layout.player,
                        t,
                      )!,
                      child: ColoredBox(
                        color: Colors.black,
                        child: LayoutBuilder(
                          builder: (context, playerBox) => widget.playerBuilder(
                            playerBox.maxWidth,
                            playerBox.maxHeight,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
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
                            shadowColor: colors.shadow.withValues(alpha: .24),
                            borderRadius: BorderRadius.circular(
                              lerpDouble(28, 20, t)!,
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
                                          child: MediaQuery(
                                            data: MediaQuery.of(context)
                                                .copyWith(
                                                  size: card.size,
                                                  padding: EdgeInsets.zero,
                                                  viewPadding: EdgeInsets.zero,
                                                ),
                                            child: ExcludeFocus(
                                              excluding: !_open,
                                              child: TickerMode(
                                                enabled: _open,
                                                child: MiniScaffold(
                                                  key: widget.sheetKey,
                                                  body: _cardContent(
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
                                              color:
                                                  colors.onSecondaryContainer,
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
                  ],
                );
              },
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
            IconButton(
              tooltip: '收起内容卡片',
              onPressed: _toggle,
              icon: const Icon(Icons.close_rounded),
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
