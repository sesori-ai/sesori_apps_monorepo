import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_harness_unavailable_notice.dart";
import "package:sesori_app_ui/src/widgets/bridge_update_sheet.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart" show BridgeKind;
import "package:theme_prego/module_prego.dart";

Widget _app({required Widget child, required BridgeKind? bridgeKind}) => BlocProvider(
  create: (_) => testBridgeKindCubit(kind: bridgeKind),
  child: MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

Widget _openButton({required BridgeKind? bridgeKind}) => _app(
  bridgeKind: bridgeKind,
  child: Builder(
    builder: (context) => TextButton(
      onPressed: () => showBridgeUpdateSheet(context: context),
      child: const Text("open"),
    ),
  ),
);

Widget _notice({required SessionInteractionState interaction, required VoidCallback onOpenHarnessSettings}) => _app(
  bridgeKind: null,
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
    await tester.pumpWidget(_openButton(bridgeKind: BridgeKind.cli));
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.text("Update Sesori Bridge"), findsOneWidget);
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

  testWidgets("before a bridge connects, the sheet shows the command-line steps", (tester) async {
    await tester.pumpWidget(_openButton(bridgeKind: null));
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.text("Update Sesori Bridge"), findsOneWidget);
    expect(find.text(BridgeInstall.updateCommand), findsOneWidget);
  });

  testWidgets("a bridge inside Sesori Desktop gets the app's update steps and no terminal commands", (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") copied.add((call.arguments as Map)["text"] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_openButton(bridgeKind: BridgeKind.desktop));
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.text("Update Sesori Desktop"), findsOneWidget);
    expect(find.text("Update Sesori Bridge"), findsNothing);
    expect(find.text("This bridge runs inside Sesori Desktop. On that computer:"), findsOneWidget);
    expect(find.text("1. Download the latest version:"), findsOneWidget);
    expect(find.text("2. Quit Sesori Desktop (closing the window doesn't quit it)."), findsOneWidget);
    expect(find.text("3. Install the new version, then open Sesori Desktop again."), findsOneWidget);
    expect(find.text(BridgeInstall.updateCommand), findsNothing);
    expect(find.text(BridgeInstall.macLinuxCommand), findsNothing);
    expect(find.byTooltip("Copy command"), findsNothing);

    await tester.tap(find.byTooltip("Copy link"));
    await tester.pump();

    expect(copied, ["sesori.com/desktop"]);
    await tester.pump(const Duration(seconds: 2));
  });
}
