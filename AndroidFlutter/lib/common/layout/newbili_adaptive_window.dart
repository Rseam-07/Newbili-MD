import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum NewbiliControlEdge { bottom, leading, trailing }

/// Scene-local UIKit geometry. Points are converted against the current Flutter
/// viewport; no device names, screen resolutions or guessed hinge positions.
@immutable
class NewbiliWindowInfo {
  const NewbiliWindowInfo({
    this.size = Size.zero,
    this.regularWidth = false,
    this.phone = false,
    this.controlEdge = NewbiliControlEdge.bottom,
    this.features = const [],
    this.nativeFoldApi = false,
  });

  final Size size;
  final bool regularWidth;
  final bool phone;
  final NewbiliControlEdge controlEdge;
  final List<DisplayFeature> features;
  final bool nativeFoldApi;

  factory NewbiliWindowInfo.fromMap(Map<Object?, Object?> data) {
    double number(Object? value) =>
        value is num && value.isFinite ? value.toDouble() : 0;
    final features = <DisplayFeature>[];
    for (final raw in (data['regions'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final width = number(raw['width']);
      final height = number(raw['height']);
      if (width < 0 || height < 0) continue;
      final division = raw['kind'] == 'division';
      features.add(
        DisplayFeature(
          bounds: Rect.fromLTWH(
            number(raw['x']),
            number(raw['y']),
            width,
            height,
          ),
          type: division ? DisplayFeatureType.fold : DisplayFeatureType.cutout,
          state: !division
              ? DisplayFeatureState.unknown
              : raw['active'] == true
              ? DisplayFeatureState.postureHalfOpened
              : DisplayFeatureState.postureFlat,
        ),
      );
    }
    return NewbiliWindowInfo(
      size: Size(number(data['width']), number(data['height'])),
      regularWidth: data['regularWidth'] == true,
      phone: data['phone'] == true,
      nativeFoldApi: data['nativeFoldApi'] == true,
      controlEdge: switch (data['controlEdge']) {
        'leading' => NewbiliControlEdge.leading,
        'trailing' => NewbiliControlEdge.trailing,
        _ => NewbiliControlEdge.bottom,
      },
      features: List.unmodifiable(features),
    );
  }

  List<DisplayFeature> featuresFor(Size viewport) {
    // Reject stale portrait/landscape geometry while the scene is resizing.
    if (size.isEmpty ||
        viewport.isEmpty ||
        (size.width - viewport.width).abs() > 2 ||
        (size.height - viewport.height).abs() > 2) {
      return const [];
    }
    final sx = viewport.width / size.width;
    final sy = viewport.height / size.height;
    return [
      for (final feature in features)
        DisplayFeature(
          bounds: Rect.fromLTRB(
            feature.bounds.left * sx,
            feature.bounds.top * sy,
            feature.bounds.right * sx,
            feature.bounds.bottom * sy,
          ),
          type: feature.type,
          state: feature.state,
        ),
    ];
  }
}

abstract final class NewbiliWindowController {
  static const _methods = MethodChannel('com.rseam07.newbili/window');
  static const _events = EventChannel('com.rseam07.newbili/window_events');
  static final info = ValueNotifier<NewbiliWindowInfo>(
    const NewbiliWindowInfo(),
  );
  static bool _seenFold = false;
  static bool get isFoldable {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    if (view.displayFeatures.any(
      (f) =>
          f.type == DisplayFeatureType.hinge ||
          f.type == DisplayFeatureType.fold,
    )) {
      _seenFold = true;
    }
    return _seenFold;
  }

  static bool get freeRotation {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return isFoldable ||
        info.value.phone && info.value.regularWidth ||
        (view.physicalSize / view.devicePixelRatio).shortestSide >= 600;
  }

  static void _accept(Object? event) {
    if (event is! Map) return;
    final next = NewbiliWindowInfo.fromMap(event);
    if (next.size.isEmpty) return;
    if (next.phone &&
            (next.regularWidth ||
                next.controlEdge != NewbiliControlEdge.bottom) ||
        next.features.any((f) => f.type == DisplayFeatureType.fold)) {
      _seenFold = true;
    }
    info.value = next;
  }

  static Future<void> initialize() async {
    if (!Platform.isIOS) return;
    try {
      _accept(await _methods.invokeMethod<Object?>('getWindow'));
    } on MissingPluginException {
      /* Older host: Flutter geometry still works. */
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('Window: ${e.code}');
    }
  }

  static StreamSubscription<Object?>? listen() => Platform.isIOS
      ? _events.receiveBroadcastStream().listen(
          _accept,
          onError: (Object e) {
            if (kDebugMode) debugPrint('Window events: ${e.runtimeType}');
          },
        )
      : null;
}

/// Wraps the navigator once. Native geometry changes never replace its engine,
/// routes, player texture or scroll controllers.
class NewbiliAdaptiveWindow extends StatefulWidget {
  const NewbiliAdaptiveWindow({
    super.key,
    required this.child,
    this.onRotationUnlocked,
  });
  final Widget child;
  final VoidCallback? onRotationUnlocked;
  @override
  State<NewbiliAdaptiveWindow> createState() => _NewbiliAdaptiveWindowState();
}

class _NewbiliAdaptiveWindowState extends State<NewbiliAdaptiveWindow>
    with WidgetsBindingObserver {
  StreamSubscription<Object?>? _subscription;
  bool _rotationFree = false;
  bool _rotationScheduled = false;
  MediaQueryData? _lastMedia;
  Size _lastLayoutSize = const Size(320, 600);
  @override
  void initState() {
    super.initState();
    _rotationFree = NewbiliWindowController.freeRotation;
    WidgetsBinding.instance.addObserver(this);
    NewbiliWindowController.info.addListener(_geometryChanged);
    _subscription = NewbiliWindowController.listen();
  }

  @override
  void didChangeMetrics() => _geometryChanged();
  void _geometryChanged() {
    if (_rotationScheduled) return;
    _rotationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rotationScheduled = false;
      if (!mounted) return;
      final free = NewbiliWindowController.freeRotation;
      if (free && !_rotationFree) {
        widget.onRotationUnlocked?.call();
      }
      _rotationFree = free;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NewbiliWindowController.info.removeListener(_geometryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<NewbiliWindowInfo>(
        valueListenable: NewbiliWindowController.info,
        child: widget.child,
        builder: (context, info, child) => LayoutBuilder(
          builder: (context, box) {
            final empty = box.biggest.isEmpty;
            final raw = MediaQuery.of(context);
            if (!empty) {
              _lastMedia = raw;
              _lastLayoutSize = box.biggest;
            }
            final media = empty
                ? _lastMedia ?? raw.copyWith(size: _lastLayoutSize)
                : raw;
            return OverflowBox(
              minWidth: _lastLayoutSize.width,
              maxWidth: _lastLayoutSize.width,
              minHeight: _lastLayoutSize.height,
              maxHeight: _lastLayoutSize.height,
              child: IgnorePointer(
                ignoring: empty,
                child: TickerMode(
                  enabled: !empty,
                  child: NewbiliWindowScope(
                    info: info,
                    child: MediaQuery(
                      data: media.copyWith(
                        displayFeatures: [
                          ...media.displayFeatures,
                          ...info.featuresFor(media.size),
                        ],
                      ),
                      child: child!,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class NewbiliWindowScope extends InheritedWidget {
  const NewbiliWindowScope({
    super.key,
    required this.info,
    required super.child,
  });
  final NewbiliWindowInfo info;
  static NewbiliWindowInfo of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NewbiliWindowScope>()?.info ??
      const NewbiliWindowInfo();

  static bool expanded(BuildContext context, [Size? available]) {
    final size = available ?? MediaQuery.sizeOf(context);
    final info = of(context);
    // Native size class is the primary iOS signal. Also keep enough room for
    // two usable panes at large text sizes and in Split View / pinned PiP.
    return size.width >= 600 &&
        size.height >= 320 &&
        (info.regularWidth || size.shortestSide >= 600 || size.width >= 840);
  }

  static bool foldable(BuildContext context) {
    final info = of(context);
    return info.phone &&
            (info.regularWidth ||
                info.controlEdge != NewbiliControlEdge.bottom) ||
        MediaQuery.of(context).displayFeatures.any(
          (f) =>
              f.type == DisplayFeatureType.fold ||
              f.type == DisplayFeatureType.hinge,
        );
  }

  @override
  bool updateShouldNotify(NewbiliWindowScope oldWidget) =>
      info != oldWidget.info;
}
