import 'package:material_ui/material_ui.dart';

abstract final class NewbiliMotion {
  static const press = Duration(milliseconds: 90);
  static const feedback = Duration(milliseconds: 160);
  static const container = Duration(milliseconds: 300);
  static const route = Duration(milliseconds: 400);
  static const exit = Duration(milliseconds: 280);
  static const emphasized = Curves.easeInOutCubicEmphasized;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

abstract final class NewbiliMetrics {
  static const minTouchTarget = 48.0;
  static const compactRadius = 12.0;
  static const cardRadius = 12.0;
  static const chromeRadius = 16.0;
  static const paneBreakpoint = 1024.0;
}

/// iOS Reduce Motion is a separate engine flag from Android Remove Animations.
/// Observe it once at the root and expose it through the existing motion policy.
class NewbiliAccessibility extends StatefulWidget {
  const NewbiliAccessibility({super.key, required this.child});
  final Widget child;
  @override
  State<NewbiliAccessibility> createState() => _NewbiliAccessibilityState();
}

class _NewbiliAccessibilityState extends State<NewbiliAccessibility>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations:
          MediaQuery.disableAnimationsOf(context) ||
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .reduceMotion,
    ),
    child: widget.child,
  );
}
