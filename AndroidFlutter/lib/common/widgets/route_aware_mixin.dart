import 'package:flutter/widgets.dart';
import 'package:PiliPlus/common/widgets/image_viewer/hero_dialog_route.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/routes/default_route.dart'
    show GetPageRoute;

// Player lifecycle follows pages. Menus and bottom sheets keep its surface live.
final routeObserver = PlaybackRouteObserver();

/// Image heroes need a PageRoute, but viewing a picture is not leaving playback.
class PlaybackRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is HeroDialogRoute) return;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is HeroDialogRoute) return;
    super.didPop(route, previousRoute);
  }
}

mixin RouteAwareMixin<T extends StatefulWidget> on State<T>, RouteAware {
  @override
  void initState() {
    super.initState();
    routeObserver.subscribe(this, Get.routing.route as GetPageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }
}
