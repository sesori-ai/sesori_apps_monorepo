import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final mode in PregoInteractionMode.values) {
    testWidgets("the harness trigger unfolds under the phone's caret under ${mode.name}", (tester) async {
      await tester.pumpWidget(
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

      final caret = find.descendant(
        of: find.byKey(const Key("new_session_plugin_trigger")),
        matching: find.byType(Icon),
      );
      expect(tester.widget<Icon>(caret.last).icon, TablerRegular.chevron_down);
    });
  }
}
