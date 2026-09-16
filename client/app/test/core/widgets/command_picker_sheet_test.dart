import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

CommandInfo _command({
  required String name,
  required String? description,
  required List<String>? hints,
  required CommandSource? source,
}) {
  return CommandInfo(
    name: name,
    template: null,
    hints: hints,
    description: description,
    agent: null,
    model: null,
    provider: null,
    source: source,
    subtask: null,
  );
}

List<CommandInfo> _commands() {
  return [
    _command(name: "release", description: "Cut a release", hints: ["version"], source: CommandSource.command),
    _command(name: "deploy", description: "Ship the app", hints: null, source: CommandSource.command),
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
    theme: buildPregoThemeData(brightness: Brightness.light),
    darkTheme: buildPregoThemeData(brightness: Brightness.dark),
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
    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.text("/deploy"), findsNothing);

    await _waitForEntries(tester, until: find.text("/deploy"));

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.text("/release"), findsOneWidget);
    expect(find.text("Ship the app"), findsOneWidget);
    expect(find.text("version"), findsOneWidget);
    expect(find.byType(PregoInputField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.hintText, "Name, description, or arguments");
    expect(find.byType(PregoGroupedRows), findsNWidgets(2));
    expect(find.byType(PregoGroupedRow), findsNWidgets(2));
    expect(find.byType(PregoTag), findsNWidgets(2));
    expect(tester.getTopLeft(find.text("/deploy")).dy, lessThan(tester.getTopLeft(find.text("/release")).dy));
  });

  for (final query in ["  RELEASE  ", "Cut a release", "version"]) {
    testWidgets("search filters by name, description, or hints: $query", (tester) async {
      await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (_) {}));

      await _openPicker(tester);
      await _waitForEntries(tester, until: find.text("/deploy"));

      await tester.enterText(find.byType(TextField), query);
      await tester.pump();

      expect(find.text("/release"), findsOneWidget);
      expect(find.text("/deploy"), findsNothing);

      await tester.enterText(find.byType(TextField), "");
      await tester.pump();
      expect(find.text("/release"), findsOneWidget);
      expect(find.text("/deploy"), findsOneWidget);
    });
  }

  testWidgets("keeps a query typed while commands are loading", (tester) async {
    await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (_) {}));
    await _openPicker(tester);
    expect(find.byType(PregoActivityIndicator), findsOneWidget);

    await tester.enterText(find.byType(TextField), "version");
    await _waitForEntries(tester, until: find.text("/release"));

    expect(find.text("/deploy"), findsNothing);
  });

  testWidgets("shows every source label, including custom and missing sources", (tester) async {
    final sources = [...CommandSource.values, null];
    await tester.pumpWidget(
      _buildApp(
        commands: [
          for (var i = 0; i < sources.length; i++)
            _command(name: "command-$i", description: null, hints: null, source: sources[i]),
        ],
        onClosed: (_) {},
      ),
    );
    await _openPicker(tester);
    await _waitForEntries(tester, until: find.text("/command-0"));

    expect(find.widgetWithText(PregoTag, "Command"), findsOneWidget);
    expect(find.widgetWithText(PregoTag, "MCP"), findsOneWidget);
    expect(find.widgetWithText(PregoTag, "Skill"), findsOneWidget);
    expect(find.widgetWithText(PregoTag, "Custom"), findsNWidgets(2));
    expect(tester.takeException(), isNull);
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

    expect(selected, _commands().last);
    expect(find.text("Slash commands"), findsNothing);
  });

  testWidgets("shows the empty message when no commands are available", (tester) async {
    await tester.pumpWidget(_buildApp(commands: const [], onClosed: (_) {}));

    await _openPicker(tester);
    await _waitForEntries(
      tester,
      until: find.text("No slash commands are available for this project."),
    );

    expect(find.byType(PregoActivityIndicator), findsNothing);
  });

  testWidgets("can recover from a search with no matches", (tester) async {
    await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (_) {}));
    await _openPicker(tester);
    await _waitForEntries(tester, until: find.text("/deploy"));

    await tester.enterText(find.byType(TextField), "not-a-command");
    await tester.pump();
    expect(find.text("No slash commands are available for this project."), findsOneWidget);
    expect(find.byType(PregoGroupedRow), findsNothing);

    await tester.enterText(find.byType(TextField), "deploy");
    await tester.pump();
    expect(find.text("/deploy"), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets("long content fits a narrow picker with large text in ${brightness.name} mode", (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      final command = _command(
        name: "namespace:review-a-long-command-name-with-arguments",
        description: "Review every changed file and explain the important findings in detail.",
        hints: ["a-long-argument-name", "another-argument-name"],
        source: CommandSource.command,
      );
      CommandInfo? selected;
      await tester.pumpWidget(_buildApp(commands: [command], onClosed: (command) => selected = command));
      await _openPicker(tester);
      await _waitForEntries(tester, until: find.text("/${command.name}"));
      await tester.pump(const Duration(milliseconds: 400));

      final card = tester.getRect(find.byType(PregoGroupedRows));
      final tag = tester.getRect(find.byType(PregoTag));
      expect(card.left, greaterThanOrEqualTo(PregoSpacing.xl));
      expect(card.right, lessThanOrEqualTo(320 - PregoSpacing.xl));
      expect(tag.right, lessThan(card.right));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text("/${command.name}"));
      await tester.pumpAndSettle();
      expect(selected, command);
    });
  }

  testWidgets("keeps a large catalog lazy and the last row reachable above the keyboard", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final commands = [
      for (var i = 0; i < 40; i++)
        _command(
          name: "command-${i.toString().padLeft(2, "0")}",
          description: "A command description",
          hints: ["argument"],
          source: CommandSource.skill,
        ),
    ];
    CommandInfo? selected;
    await tester.pumpWidget(_buildApp(commands: commands, onClosed: (command) => selected = command));
    await _openPicker(tester);
    await _waitForEntries(tester, until: find.text("/command-00"));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PregoGroupedRow).evaluate().length, lessThan(commands.length));
    expect(find.text("/command-39"), findsNothing);

    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text("/command-39"),
      250,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();

    final lastCard = find.ancestor(of: find.text("/command-39"), matching: find.byType(PregoGroupedRows));
    expect(tester.getBottomRight(lastCard).dy, lessThanOrEqualTo(844 - 300));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("/command-39"));
    await tester.pumpAndSettle();
    expect(selected, commands.last);
  });

  testWidgets("caps the body at the space left below the sheet header", (tester) async {
    // A status bar tall enough that the default 70%-of-screen body no longer
    // fits under the sheet header: the body must cap at the remaining space
    // (mirroring the model picker) instead of giving the outer sheet scroll
    // range of its own on top of the inner list.
    const topInset = 140.0;
    final dpr = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(top: topInset * dpr);
    tester.view.viewPadding = FakeViewPadding(top: topInset * dpr);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp(commands: _commands(), onClosed: (_) {}));
    await _openPicker(tester);
    // Let the sheet's entrance animation finish before measuring.
    await tester.pump(const Duration(milliseconds: 400));

    final screenHeight = tester.view.physicalSize.height / dpr;
    final maxBody = screenHeight - topInset - PregoBottomSheet.contentTopInset;
    // Premise guard: the cap must actually bite in this geometry, otherwise
    // this test silently stops exercising it.
    expect(maxBody, lessThan(screenHeight * 0.7));

    expect(
      tester.getSize(find.byType(CommandPickerSheet)).height,
      moreOrLessEquals(maxBody),
    );
  });
}
