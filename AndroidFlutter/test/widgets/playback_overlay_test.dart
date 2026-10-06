import 'package:PiliPlus/common/widgets/image_viewer/hero_dialog_route.dart';
import 'package:PiliPlus/common/widgets/newbili_cover_hero.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _PlaybackProbe with RouteAware {
  int paused = 0;
  int reloaded = 0;
  @override
  void didPushNext() => paused++;
  @override
  void didPopNext() => reloaded++;
}

void main() {
  testWidgets('image hero overlay never pauses or reloads the playback route', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final observer = PlaybackRouteObserver();
    final probe = _PlaybackProbe();
    final surface = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [observer],
        home: Scaffold(
          body: NewbiliCoverHero(
            tag: 'playing-cover',
            child: StatefulBuilder(
              key: surface,
              builder: (_, _) => const Text('playing'),
            ),
          ),
        ),
      ),
    );
    final playerState = surface.currentState;
    observer.subscribe(
      probe,
      ModalRoute.of(tester.element(find.text('playing')))! as PageRoute,
    );
    addTearDown(() => observer.unsubscribe(probe));
    nav.currentState!.push(
      HeroDialogRoute<void>(
        pageBuilder: (_, _, _) =>
            const Material(child: Text('comment picture')),
      ),
    );
    await tester.pumpAndSettle();
    expect(probe.paused, 0);
    expect(surface.currentState, same(playerState));
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(probe.reloaded, 0);
    expect(surface.currentState, same(playerState));
    // Actual navigation still follows the original player lifecycle.
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('another video')),
    );
    await tester.pumpAndSettle();
    expect(probe.paused, 1);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(probe.reloaded, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
