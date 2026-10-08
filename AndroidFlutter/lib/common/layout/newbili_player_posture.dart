import 'package:flutter/widgets.dart';

class NewbiliPlayerPosture extends InheritedWidget {
  const NewbiliPlayerPosture({
    super.key,
    required this.tabletop,
    required super.child,
  });
  final bool tabletop;
  static bool tabletopOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NewbiliPlayerPosture>()
          ?.tabletop ??
      false;
  @override
  bool updateShouldNotify(NewbiliPlayerPosture oldWidget) =>
      tabletop != oldWidget.tabletop;
}
