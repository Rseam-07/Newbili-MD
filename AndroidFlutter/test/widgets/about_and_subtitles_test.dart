import 'package:PiliPlus/pages/about/view.dart';
import 'package:PiliPlus/pages/video/widgets/subtitle_language_dialog.dart';
import 'package:PiliPlus/router/app_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('registered about route opens with metadata and support links', (
    tester,
  ) async {
    final page = Routes.getPages.singleWhere((page) => page.name == '/about');
    expect(page.page(), isA<AboutPage>());
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(Get.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.pink,
            brightness: Brightness.dark,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(),
        getPages: [
          GetPage(
            name: '/about',
            page: () => AboutPage(loadCacheSize: () async => 0),
          ),
        ],
      ),
    );
    Get.toNamed<void>('/about');
    await tester.pumpAndSettle();
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('Newbili MD'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('下载与更新日志'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('下载与更新日志').hitTestable(), findsOneWidget);
    expect(find.text('官方网站'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Get.back<void>();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'bilingual picker excludes duplicate languages and can turn off',
    (tester) async {
      ({int primary, int secondary})? choice;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSubtitleLanguages(
                context,
                languages: const ['中文', 'English'],
                primaryIndex: 1,
                secondaryIndex: 2,
                onApply: (primary, secondary) async =>
                    choice = (primary: primary, secondary: secondary),
              ),
              child: const Text('选择字幕'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('选择字幕'));
      await tester.pumpAndSettle();
      final menus = tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .toList();
      final buttons = tester
          .widgetList<DropdownButton<int>>(
            find.byType(DropdownButton<int>),
          )
          .toList();
      expect(buttons[1].items!.map((item) => item.value), [0, 2]);
      menus[0].onChanged!(0);
      await tester.pumpAndSettle();
      final second = tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .last;
      expect(second.onChanged, isNull);
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(choice, (primary: 0, secondary: 0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
