import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// Visual-only feedback; child recognizers still own taps, scrolls and Hero.
/// Idle widgets do not tick. Scroll movement cancels the pressed pose.
class NewbiliPressFeedback extends StatefulWidget {
  const NewbiliPressFeedback({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = .975,
    this.hoverScale = 1.012,
  });
  final Widget child;
  final bool enabled;
  final double pressedScale;
  final double hoverScale;
  @override
  State<NewbiliPressFeedback> createState() => _NewbiliPressFeedbackState();
}

class _NewbiliPressFeedbackState extends State<NewbiliPressFeedback>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _reduced = false;
  int? _pointer;
  Offset? _origin;
  bool _hovered = false;
  void _animate() {
    final target = !widget.enabled || _reduced
        ? 1.0
        : _pointer != null
        ? widget.pressedScale
        : _hovered
        ? widget.hoverScale
        : 1.0;
    if (_reduced || !widget.enabled) {
      _scale.value = 1;
    } else if (_pointer != null) {
      _scale.animateTo(
        target,
        duration: NewbiliMotion.press,
        curve: Curves.easeOutCubic,
      );
    } else {
      _scale.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 430, damping: 40),
          _scale.value,
          target,
          _scale.velocity,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = NewbiliMotion.reduced(context);
    if (_reduced) _scale.value = 1;
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _release() {
    if (_pointer == null) return;
    _pointer = null;
    _origin = null;
    _animate();
  }

  @override
  void didUpdateWidget(NewbiliPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointer = null;
      _origin = null;
      _hovered = false;
      _animate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) {
          _hovered = true;
          _animate();
        }
      },
      onExit: (_) {
        if (_hovered) {
          _hovered = false;
          _animate();
        }
      },
      child: Listener(
        onPointerDown: (event) {
          if (!widget.enabled) return;
          if (_pointer != null) {
            _release();
            return;
          }
          _pointer = event.pointer;
          _origin = event.position;
          _animate();
        },
        onPointerMove: (event) {
          if (event.pointer == _pointer &&
              (event.position - _origin!).distance > 12) {
            _release();
          }
        },
        onPointerUp: (event) {
          if (event.pointer == _pointer) _release();
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) _release();
        },
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
