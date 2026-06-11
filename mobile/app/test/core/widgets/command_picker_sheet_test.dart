import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/widgets/command_picker_sheet.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

CommandInfo _command({
  required String name,
  String? description,
  List<String>? hints,
}) {
  return CommandInfo(
    name: name,
    template: null,
    hints: hints,
    description: description,
    agent: null,
    model: null,
    provider: null,
    source: CommandSource.command,
    subtask: null,
  );
}

List<CommandInfo> _commands() {
  return [
    _command(name: "release", description: "Cut a release", hints: ["version"]),
    _command(name: "deploy", description: "Ship the app"),
  ];
}

Widget _buildApp({
  required List<CommandInfo> commands,
  required ValueChanged<CommandInfo?> onClosed,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final selected = await CommandPickerSheet.show(context, commands: commands);
              onClosed(selected);
            },
            child: const Text("Open picker"),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(
      extensions: [ZyraDesignSystem.light],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

/// Opens the picker. The entry computation runs in a real isolate via
/// compute(), which the fake-async test clock cannot settle on its own, so
/// the sheet deterministically shows its loading state at this point.
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text("Open picker"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Lets the compute() isolate finish and the sheet rebuild with its result.
/// Alternates [WidgetTester.runAsync] and [WidgetTester.pump]; pumpAndSettle
/// cannot be used with compute's real isolates.
Future<void> _waitForEntries(WidgetTester tester, {required Finder until}) async {
  for (var i = 0; i < 40 && until.evaluate().isEmpty; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  expect(until, findsWidgets, reason: "command picker content did not finish loading");
}

void main() {
  testWidgets("opens with a loading indicator, then shows the sorted commands", (tester) async {
    await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (_) {}));

    await _openPicker(tester);

    expect(find.text("Slash commands"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("/deploy"), findsNothing);

    await _waitForEntries(tester, until: find.text("/deploy"));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("/release"), findsOneWidget);
    expect(find.text("Ship the app"), findsOneWidget);
    expect(find.text("version"), findsOneWidget);
  });

  testWidgets("search filters commands by name, description, and hints", (tester) async {
    await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (_) {}));

    await _openPicker(tester);
    await _waitForEntries(tester, until: find.text("/deploy"));

    await tester.enterText(find.byType(TextField), "Ship");
    await tester.pump();

    expect(find.text("/deploy"), findsOneWidget);
    expect(find.text("/release"), findsNothing);
  });

  testWidgets("tapping a command returns it through the show() future and closes the sheet", (tester) async {
    CommandInfo? selected;
    await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (command) => selected = command));

    await _openPicker(tester);
    await _waitForEntries(tester, until: find.text("/deploy"));
    // Let the sheet's entrance animation finish: while the route is still
    // animating, the navigator ignores pointer events on its content.
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text("/deploy"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(selected?.name, "deploy");
    expect(find.text("Slash commands"), findsNothing);
  });

  testWidgets("shows the empty message when no commands are available", (tester) async {
    await tester.pumpWidget(_buildApp(commands: const [], onClosed: (_) {}));

    await _openPicker(tester);
    await _waitForEntries(
      tester,
      until: find.text("No slash commands are available for this project."),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
