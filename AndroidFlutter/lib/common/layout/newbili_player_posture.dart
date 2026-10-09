import 'package:flutter/widgets.dart';

class NewbiliPlayerPosture extends InheritedWidget {
  const NewbiliPlayerPosture({
    super.key,
    required this.tabletop,
    this.edgeControls = false,
    required super.child,
  });
  final bool tabletop;
  final bool edgeControls;
  static bool edgeControlsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NewbiliPlayerPosture>()
          ?.edgeControls ??
      false;
  static bool tabletopOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NewbiliPlayerPosture>()
          ?.tabletop ??
      false;
  @override
  bool updateShouldNotify(NewbiliPlayerPosture oldWidget) =>
      tabletop != oldWidget.tabletop || edgeControls != oldWidget.edgeControls;
}
