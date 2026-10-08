import 'package:PiliPlus/common/widgets/newbili_press_feedback.dart';
import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The root navigation occupies its own layout space, including the system inset.
class NewbiliNavigationBar extends StatelessWidget {
  const NewbiliNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static double heightOf(BuildContext context) =>
      64 + (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0.0, 24.0);

  // MainLayout already reserves the bar's full height. Lists need only a gutter.
  static double bottomContentInsetOf(BuildContext context) => 16;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final duration = NewbiliMotion.duration(context, NewbiliMotion.container);
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
          ),
        ),
        child: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: SizedBox(
            height: heightOf(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / destinations.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: duration,
                      curve: NewbiliMotion.emphasized,
                      left: width * selectedIndex + (width - 18) / 2,
                      top: 0,
                      child: Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: Semantics(
                              label: destinations[i].label,
                              button: true,
                              selected: i == selectedIndex,
                              child: InkResponse(
                                key: ValueKey('newbili-destination-$i'),
                                onTap: () => onDestinationSelected(i),
                                containedInkWell: true,
                                highlightShape: BoxShape.rectangle,
                                child: ExcludeSemantics(
                                  child: SizedBox.expand(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AnimatedTheme(
                                          duration: duration,
                                          data: Theme.of(context).copyWith(
                                            iconTheme: IconThemeData(
                                              size: 24,
                                              color: i == selectedIndex
                                                  ? colors.primary
                                                  : colors.onSurfaceVariant,
                                            ),
                                          ),
                                          child: NewbiliPressFeedback(
                                            child: AnimatedScale(
                                              scale: i == selectedIndex
                                                  ? 1.08
                                                  : 1,
                                              duration: duration,
                                              curve: Curves.easeOutCubic,
                                              child: AnimatedSwitcher(
                                                duration:
                                                    NewbiliMotion.duration(
                                                      context,
                                                      NewbiliMotion.feedback,
                                                    ),
                                                child: KeyedSubtree(
                                                  key: ValueKey(
                                                    i == selectedIndex,
                                                  ),
                                                  child: i == selectedIndex
                                                      ? destinations[i]
                                                                .selectedIcon ??
                                                            destinations[i].icon
                                                      : destinations[i].icon,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        AnimatedDefaultTextStyle(
                                          duration: duration,
                                          style: TextStyle(
                                            fontFamily: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.fontFamily,
                                            fontSize: 11,
                                            height: 1.2,
                                            fontWeight: i == selectedIndex
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: i == selectedIndex
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                          ),
                                          child: Text(
                                            destinations[i].label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Duo places navigation on the reachable outer edge. It scrolls when system
/// chrome, the keyboard or large type leaves less vertical room.
class NewbiliEdgeNavigationBar extends StatelessWidget {
  const NewbiliEdgeNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.header,
  });
  static const width = 80.0;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? header;
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        child: SizedBox(
          width: width,
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (header != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: header!,
                      ),
                    for (var i = 0; i < destinations.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Semantics(
                          selected: i == selectedIndex,
                          button: true,
                          label: destinations[i].label,
                          child: Tooltip(
                            message: destinations[i].label,
                            child: InkWell(
                              key: ValueKey('edge-destination-$i'),
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => onDestinationSelected(i),
                              child: AnimatedContainer(
                                duration: NewbiliMotion.duration(
                                  context,
                                  NewbiliMotion.container,
                                ),
                                curve: NewbiliMotion.emphasized,
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                  minWidth: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: i == selectedIndex
                                      ? colors.secondaryContainer
                                      : Colors.transparent,
                                ),
                                child: ExcludeSemantics(
                                  child: Column(
                                    children: [
                                      IconTheme(
                                        data: IconThemeData(
                                          size: 24,
                                          color: i == selectedIndex
                                              ? colors.onSecondaryContainer
                                              : colors.onSurfaceVariant,
                                        ),
                                        child: i == selectedIndex
                                            ? destinations[i].selectedIcon ??
                                                  destinations[i].icon
                                            : destinations[i].icon,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        destinations[i].label,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
