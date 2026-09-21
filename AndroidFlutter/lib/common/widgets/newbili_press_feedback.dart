import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Visual-only feedback; child recognizers still own taps, scrolls and Hero.
/// Idle widgets do not tick. Scroll movement cancels the pressed pose.
class NewbiliPressFeedback extends StatefulWidget {
  const NewbiliPressFeedback({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;
  @override
  State<NewbiliPressFeedback> createState() => _NewbiliPressFeedbackState();
}

class _NewbiliPressFeedbackState extends State<NewbiliPressFeedback> {
  int? _pointer;
  Offset? _origin;
  bool _hovered = false;
  void _release() {
    if (_pointer == null) return;
    setState(() {
      _pointer = null;
      _origin = null;
    });
  }

  @override
  void didUpdateWidget(NewbiliPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointer = null;
      _origin = null;
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = NewbiliMotion.reduced(context);
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Listener(
        onPointerDown: (event) {
          if (!widget.enabled || _pointer != null) return;
          setState(() {
            _pointer = event.pointer;
            _origin = event.position;
          });
        },
        onPointerMove: (event) {
          if (event.pointer == _pointer &&
              (event.position - _origin!).distance > 12)
            _release();
        },
        onPointerUp: (event) {
          if (event.pointer == _pointer) _release();
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) _release();
        },
        child: AnimatedScale(
          scale: reduced
              ? 1
              : _pointer != null
              ? .975
              : _hovered
              ? 1.012
              : 1,
          duration: NewbiliMotion.duration(
            context,
            _pointer != null ? NewbiliMotion.feedback : NewbiliMotion.container,
          ),
          curve: _pointer != null ? Curves.easeOutCubic : Curves.easeOutQuint,
          child: widget.child,
        ),
      ),
    );
  }
}
