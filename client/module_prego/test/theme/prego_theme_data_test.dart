import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  test("styles resolve the bundled font without qualifying system fallbacks or overrides", () {
    expect(PregoTextTheme.fontFamily, "packages/theme_prego/Satoshi Prego");
    for (final typography in [PregoTextTheme.light, PregoTextTheme.dark]) {
      for (final style in [typography.textSm.regular, typography.textMd.medium, typography.textLg.bold]) {
        expect(style.fontFamily, PregoTextTheme.fontFamily);
        expect(style.fontFamilyFallback, PregoTextTheme.fontFamilyFallback);
        expect(style.copyWith(fontFamily: "monospace").fontFamily, "monospace");
      }
    }
  });

  test("assembles the complete light Prego Material theme", () {
    final ThemeData theme = buildPregoThemeData(brightness: Brightness.light);

    expect(theme.colorScheme, PregoColors.light.toFlutterColorScheme());
    expect(theme.textTheme.bodyLarge?.fontFamily, PregoTextTheme.fontFamily);
    expect(theme.textTheme.bodyLarge?.color, PregoTextTheme.light.asFlutterTextTheme().bodyLarge.color);
    expect(theme.extension<PregoDesignSystem>(), same(PregoDesignSystem.light));
    expect(theme.scaffoldBackgroundColor, PregoDesignSystem.light.colors.bgSurface1);
    expect(theme.appBarTheme.systemOverlayStyle, SystemUiOverlayStyle.dark);
  });

  test("assembles the complete dark Prego Material theme", () {
    final ThemeData theme = buildPregoThemeData(brightness: Brightness.dark);

    expect(theme.colorScheme, PregoColors.dark.toFlutterColorScheme());
    expect(theme.textTheme.bodyLarge?.fontFamily, PregoTextTheme.fontFamily);
    expect(theme.textTheme.bodyLarge?.color, PregoTextTheme.dark.asFlutterTextTheme().bodyLarge.color);
    expect(theme.extension<PregoDesignSystem>(), same(PregoDesignSystem.dark));
    expect(theme.scaffoldBackgroundColor, PregoDesignSystem.dark.colors.bgSurface1);
    expect(theme.appBarTheme.systemOverlayStyle, SystemUiOverlayStyle.light);
  });

  testWidgets("buttons show the hand cursor on desktop, and a disabled one does not", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              IconButton(key: const Key("enabled"), onPressed: () {}, icon: const Icon(Icons.add)),
              const IconButton(key: Key("disabled"), onPressed: null, icon: Icon(Icons.add)),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 1);
    await gesture.addPointer(location: tester.getCenter(find.byKey(const Key("enabled"))));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    await gesture.moveTo(tester.getCenter(find.byKey(const Key("disabled"))));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
