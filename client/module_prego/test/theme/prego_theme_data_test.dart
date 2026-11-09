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

  test("desktop transcripts read at the phone's size while the interface stays compact", () {
    for (final (desktop, phone) in [
      (PregoTextTheme.desktopLight, PregoTextTheme.light),
      (PregoTextTheme.desktopDark, PregoTextTheme.dark),
    ]) {
      expect(desktop.chat.regular.fontSize, 14);
      expect(desktop.chat.regular.height, 20 / 14);
      expect(desktop.chat.regular.fontSize, phone.chat.regular.fontSize);
      expect(desktop.chat.regular.height, phone.chat.regular.height);
      expect(desktop.inlineCodeSize, 13);
      expect(desktop.inlineCodeSize, phone.inlineCodeSize);
      expect(desktop.code, phone.code);
      expect(desktop.textMd.regular.fontSize, lessThan(phone.textMd.regular.fontSize ?? 0));
    }
  });

  test("a rebuilt theme equals the last, so the app does not animate between them", () {
    for (final brightness in Brightness.values) {
      expect(buildPregoThemeData(brightness: brightness), buildPregoThemeData(brightness: brightness));
      expect(buildPregoDesktopThemeData(brightness: brightness), buildPregoDesktopThemeData(brightness: brightness));
    }
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
