import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Future<void> pumpChooser(WidgetTester tester, {required PregoInteractionMode mode}) => tester.pumpWidget(
    PregoInteractionScope(
      mode: mode,
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NewSessionPluginChooser(
            plugins: const [
              PluginMetadata(
                id: "claude",
                displayName: "Claude Code",
                isDefault: true,
                state: PluginLifecycleState.ready,
                actionHint: null,
                failureBlock: null,
                mcpScopes: null,
              ),
            ],
            selectedPluginId: "claude",
            isSelectionEnabled: true,
            onSelected: (_) {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    ),
  );

  for (final mode in PregoInteractionMode.values) {
    testWidgets("the harness trigger unfolds under the phone's caret under ${mode.name}", (tester) async {
      await pumpChooser(tester, mode: mode);

      final caret = find.descendant(
        of: find.byKey(const Key("new_session_plugin_trigger")),
        matching: find.byType(Icon),
      );
      expect(tester.widget<Icon>(caret.last).icon, TablerRegular.chevron_down);
    });

    testWidgets("the harness menu's title is a section heading in spaced capitals under ${mode.name}", (
      tester,
    ) async {
      await pumpChooser(tester, mode: mode);
      await tester.tap(find.byKey(const Key("new_session_plugin_trigger")));
      await tester.pumpAndSettle();

      expect(find.text("Harnesses"), findsNothing);
      final title = find.text("HARNESSES");
      final style = tester.widget<Text>(title).style;
      final prego = tester.element(title).prego;
      expect(style?.letterSpacing, 0.8);
      expect(style?.fontSize, prego.textTheme.textXs.medium.fontSize);
      expect(style?.fontWeight, prego.textTheme.textXs.medium.fontWeight);
      expect(style?.color, prego.colors.textSecondary);
      expect(find.byKey(const Key("new_session_harness_settings")), findsOneWidget);
    });
  }
}
