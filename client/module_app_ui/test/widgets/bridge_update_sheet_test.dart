import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_harness_unavailable_notice.dart";
import "package:sesori_app_ui/src/widgets/bridge_update_sheet.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

Widget _app({required Widget child}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _notice({required SessionInteractionState interaction, required VoidCallback onOpenHarnessSettings}) => _app(
  child: SessionHarnessUnavailableNotice(
    interaction: interaction,
    historyUnavailable: false,
    onOpenHarnessSettings: onOpenHarnessSettings,
    onRecheck: () {},
  ),
);

void main() {
  testWidgets("an old bridge's notice opens the update steps instead of harness settings", (tester) async {
    var settingsOpened = 0;
    await tester.pumpWidget(
      _notice(
        interaction: const SessionInteractionState.legacyUnverified(),
        onOpenHarnessSettings: () => settingsOpened++,
      ),
    );

    expect(find.text("Update your bridge to check harness availability."), findsOneWidget);
    expect(find.byKey(const Key("session_harness_settings")), findsNothing);

    await tester.tap(find.byKey(const Key("session_bridge_update")));
    await tester.pumpAndSettle();

    expect(find.text("Update Sesori Bridge"), findsOneWidget);
    expect(settingsOpened, 0);
  });

  testWidgets("a blocked harness keeps its way to harness settings", (tester) async {
    var settingsOpened = 0;
    await tester.pumpWidget(
      _notice(
        interaction: const SessionInteractionState.blocked(
          reason: SessionInteractionBlockedReason.authenticationRequired,
          displayName: "Fixture Harness",
          actionHint: null,
          refreshError: null,
        ),
        onOpenHarnessSettings: () => settingsOpened++,
      ),
    );

    expect(find.byKey(const Key("session_bridge_update")), findsNothing);
    await tester.tap(find.byKey(const Key("session_harness_settings")));
    expect(settingsOpened, 1);
  });

  testWidgets("the sheet lists the update, restart, and every reinstall command, each copyable", (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") copied.add((call.arguments as Map)["text"] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      _app(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBridgeUpdateSheet(context: context),
            child: const Text("open"),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.text("On the computer running the bridge:"), findsOneWidget);
    expect(find.text("If step 1 fails or the command isn't found, reinstall:"), findsOneWidget);
    const commands = [
      BridgeInstall.updateCommand,
      BridgeInstall.runCommand,
      BridgeInstall.macLinuxCommand,
      BridgeInstall.windowsCommand,
      BridgeInstall.npmCommand,
      BridgeInstall.bunCommand,
    ];
    for (final command in commands) {
      expect(find.text(command), findsOneWidget);
    }
    expect(find.byTooltip("Copy command"), findsNWidgets(commands.length));

    final updateCopy = find.byKey(const ValueKey("bridge_update_copy_${BridgeInstall.updateCommand}"));
    await tester.tap(updateCopy);
    await tester.pump();

    expect(copied, [BridgeInstall.updateCommand]);
    expect(find.descendant(of: updateCopy, matching: find.byIcon(TablerRegular.check)), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.descendant(of: updateCopy, matching: find.byIcon(TablerRegular.copy)), findsOneWidget);
  });
}
