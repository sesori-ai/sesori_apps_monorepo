import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
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

/// A composer-like harness: the trigger sits at the bottom start corner, where
/// the composer's slash button is.
Widget _buildApp({
  required List<CommandInfo> commands,
  required ValueChanged<CommandInfo> onSelected,
  // ignore: no_slop_linter/prefer_required_named_parameters, most cases run on the phone
  PregoInteractionMode mode = PregoInteractionMode.touch,
}) {
  return PregoInteractionScope(
    mode: mode,
    child: MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      darkTheme: buildPregoThemeData(brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: PregoPickerPopover(
            pointerWidth: 360,
            triggerBuilder: (context, toggle) => TextButton(onPressed: toggle, child: const Text("Open picker")),
            contentBuilder: (context, close) => CommandPicker(
              commands: commands,
              onCommandSelected: (command) {
                close();
                onSelected(command);
              },
              onClose: close,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens the picker. The entry computation runs in a real isolate via
/// compute(), which the fake-async test clock cannot settle on its own, so
/// the picker deterministically shows its loading state at this point.
Future<void> _openPicker({required WidgetTester tester}) async {
  await tester.tap(find.text("Open picker"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Lets the compute() isolate finish and the picker rebuild with its result.
/// Alternates [WidgetTester.runAsync] and [WidgetTester.pump]; pumpAndSettle
/// cannot be used with compute's real isolates.
Future<void> _waitForEntries({required WidgetTester tester, required Finder until}) async {
  for (var i = 0; i < 40 && until.evaluate().isEmpty; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  expect(until, findsWidgets, reason: "command picker content did not finish loading");
}

Rect _panel({required WidgetTester tester}) => tester.getRect(find.byType(CommandPicker));

void main() {
  testWidgets("opens with a loading indicator, then shows the sorted commands", (tester) async {
    await tester.pumpWidget(_buildApp(commands: _commands(), onSelected: (_) {}));

    await _openPicker(tester: tester);

    expect(find.byType(CommandPicker), findsOneWidget);
    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.text("/deploy"), findsNothing);

    await _waitForEntries(tester: tester, until: find.text("/deploy"));

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.text("/release"), findsOneWidget);
    expect(find.text("Ship the app"), findsOneWidget);
    expect(find.text("version"), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.hintText, "Search commands");
    expect(find.byType(PregoTag), findsNWidgets(2));
    expect(tester.getTopLeft(find.text("/deploy")).dy, lessThan(tester.getTopLeft(find.text("/release")).dy));
  });

  for (final query in ["  RELEASE  ", "Cut a release", "version"]) {
    testWidgets("search filters by name, description, or hints: $query", (tester) async {
      await tester.pumpWidget(_buildApp(commands: _commands(), onSelected: (_) {}));

      await _openPicker(tester: tester);
      await _waitForEntries(tester: tester, until: find.text("/deploy"));

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
    await tester.pumpWidget(_buildApp(commands: _commands(), onSelected: (_) {}));
    await _openPicker(tester: tester);
    expect(find.byType(PregoActivityIndicator), findsOneWidget);

    await tester.enterText(find.byType(TextField), "version");
    await _waitForEntries(tester: tester, until: find.text("/release"));

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
        onSelected: (_) {},
      ),
    );
    await _openPicker(tester: tester);
    await _waitForEntries(tester: tester, until: find.text("/command-0"));

    expect(find.widgetWithText(PregoTag, "Command"), findsOneWidget);
    expect(find.widgetWithText(PregoTag, "MCP"), findsOneWidget);
    expect(find.widgetWithText(PregoTag, "Skill"), findsOneWidget);
    expect(find.widgetWithText(PregoTag, "Custom"), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets("tapping a command returns it and closes the picker", (tester) async {
    final selected = <CommandInfo>[];
    await tester.pumpWidget(_buildApp(commands: _commands(), onSelected: selected.add));

    await _openPicker(tester: tester);
    await _waitForEntries(tester: tester, until: find.text("/deploy"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("/deploy"));
    await tester.pumpAndSettle();

    expect(selected, [_commands().last]);
    expect(find.byType(CommandPicker), findsNothing);
  });

  testWidgets("shows the empty message when no commands are available", (tester) async {
    await tester.pumpWidget(_buildApp(commands: const [], onSelected: (_) {}));

    await _openPicker(tester: tester);
    await _waitForEntries(
      tester: tester,
      until: find.text("No slash commands are available for this project."),
    );

    expect(find.byType(PregoActivityIndicator), findsNothing);
  });

  testWidgets("can recover from a search with no matches", (tester) async {
    await tester.pumpWidget(_buildApp(commands: _commands(), onSelected: (_) {}));
    await _openPicker(tester: tester);
    await _waitForEntries(tester: tester, until: find.text("/deploy"));

    await tester.enterText(find.byType(TextField), "not-a-command");
    await tester.pump();
    expect(find.text("No slash commands are available for this project."), findsOneWidget);
    expect(find.byType(PregoTag), findsNothing);

    await tester.enterText(find.byType(TextField), "deploy");
    await tester.pump();
    expect(find.text("/deploy"), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets("long content fits a narrow phone with large text in ${brightness.name} mode", (tester) async {
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
      final selected = <CommandInfo>[];
      await tester.pumpWidget(_buildApp(commands: [command], onSelected: selected.add));
      await _openPicker(tester: tester);
      await _waitForEntries(tester: tester, until: find.text("/${command.name}"));
      await tester.pumpAndSettle();

      // On the phone the picker spans the screen inside its edge padding.
      final panel = _panel(tester: tester);
      final tag = tester.getRect(find.byType(PregoTag));
      expect(panel.left, greaterThanOrEqualTo(12));
      expect(panel.right, lessThanOrEqualTo(320 - 12));
      expect(tag.right, lessThan(panel.right));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text("/${command.name}"));
      await tester.pumpAndSettle();
      expect(selected, [command]);
    });
  }

  testWidgets("keeps a large catalog lazy and its last command reachable", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
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
    final selected = <CommandInfo>[];
    await tester.pumpWidget(_buildApp(commands: commands, onSelected: selected.add));
    await _openPicker(tester: tester);
    await _waitForEntries(tester: tester, until: find.text("/command-00"));
    await tester.pumpAndSettle();

    expect(find.byType(PregoTag).evaluate().length, lessThan(commands.length));
    expect(find.text("/command-39"), findsNothing);
    expect(_panel(tester: tester).height, lessThanOrEqualTo(PregoPickerPopover.maxHeight));

    await tester.scrollUntilVisible(
      find.text("/command-39"),
      250,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("/command-39"));
    await tester.pumpAndSettle();
    expect(selected, [commands.last]);
  });

  testWidgets("on the desktop, typing after the slash button filters and Enter picks the first match", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.reset);
    final selected = <CommandInfo>[];
    await tester.pumpWidget(
      _buildApp(commands: _commands(), onSelected: selected.add, mode: PregoInteractionMode.pointer),
    );
    await _openPicker(tester: tester);
    await _waitForEntries(tester: tester, until: find.text("/deploy"));
    await tester.pumpAndSettle();

    // The picker sits above its trigger and inside the window edge.
    final panel = _panel(tester: tester);
    expect(panel.width, lessThanOrEqualTo(360));
    expect(panel.left, greaterThanOrEqualTo(12));
    expect(panel.bottom, lessThanOrEqualTo(tester.getRect(find.text("Open picker")).top));

    // The field already has focus, so typing goes straight to the search:
    // the platform text input reaches only the focused field.
    tester.testTextInput.enterText("re");
    await tester.pump();
    expect(find.text("/deploy"), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, [_commands().first]);
    expect(find.byType(CommandPicker), findsNothing);
  });
}
