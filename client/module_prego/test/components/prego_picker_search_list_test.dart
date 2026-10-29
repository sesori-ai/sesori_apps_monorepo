import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late List<String> picked;

  setUp(() => picked = []);

  PregoPickerSearchFooterAction action(String label) => PregoPickerSearchFooterAction(
    label: label,
    icon: TablerRegular.folder,
    isSelected: false,
    onPick: () => picked.add(label),
  );

  Future<void> pumpList({required WidgetTester tester, required PregoInteractionMode mode}) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PregoInteractionScope(
        mode: mode,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: PregoPickerSearchList(
              searchHint: "Search",
              onQueryChanged: (_) {},
              footer: PregoPickerSearchFooter.pair(leading: action("Leading"), trailing: action("Trailing")),
              rows: [
                for (final name in ["first", "second"])
                  PregoPickerSearchOption(isSelected: false, onPick: () => picked.add(name), child: Text(name)),
              ],
              emptyText: null,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pill(String label) => find.ancestor(of: find.text(label), matching: find.byType(PregoButtonsSolid));

  bool highlighted({required WidgetTester tester, required String label}) {
    final ring = find.ancestor(of: pill(label), matching: find.byType(DecoratedBox)).first;
    return (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration).boxShadow != null;
  }

  Future<void> press({required WidgetTester tester, required LogicalKeyboardKey key}) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets("a pair shares the footer's width equally, leading first", (tester) async {
    await pumpList(tester: tester, mode: PregoInteractionMode.touch);

    final leading = tester.getRect(pill("Leading"));
    final trailing = tester.getRect(pill("Trailing"));
    expect(leading.width, trailing.width);
    expect(leading.top, trailing.top);
    expect(leading.right, lessThan(trailing.left));
    // Together with the gap they span the footer's padded width.
    expect(trailing.right - leading.left, greaterThan(390 - 2 * 12 - 1));
  });

  testWidgets("under a pointer Down from the last option reaches leading, then trailing, for Enter to pick", (
    tester,
  ) async {
    await pumpList(tester: tester, mode: PregoInteractionMode.pointer);
    expect(highlighted(tester: tester, label: "Leading"), isFalse);

    // From the first option, past the second, onto leading.
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    expect(highlighted(tester: tester, label: "Leading"), isTrue);
    expect(highlighted(tester: tester, label: "Trailing"), isFalse);

    // Trailing is last, where the highlight holds; Up goes back to leading.
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    expect(highlighted(tester: tester, label: "Trailing"), isTrue);
    expect(highlighted(tester: tester, label: "Leading"), isFalse);
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(picked, ["Trailing"]);

    await press(tester: tester, key: LogicalKeyboardKey.arrowUp);
    expect(highlighted(tester: tester, label: "Leading"), isTrue);
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(picked, ["Trailing", "Leading"]);
  });

  testWidgets("under a pointer Tab focuses leading before trailing", (tester) async {
    await pumpList(tester: tester, mode: PregoInteractionMode.pointer);

    String? focusedPill() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PregoButtonsSolid>()?.label;
    for (var i = 0; i < 5 && focusedPill() == null; i++) {
      await press(tester: tester, key: LogicalKeyboardKey.tab);
    }
    expect(focusedPill(), "Leading");
    // A pill can hold more than one focus stop.
    for (var i = 0; i < 3 && focusedPill() == "Leading"; i++) {
      await press(tester: tester, key: LogicalKeyboardKey.tab);
    }
    expect(focusedPill(), "Trailing");
  });

  testWidgets("rows added for the same query keep the option the user moved to; a new query starts from the top", (
    tester,
  ) async {
    final names = ValueNotifier(["first", "second"]);
    addTearDown(names.dispose);
    await tester.pumpWidget(
      PregoInteractionScope(
        mode: PregoInteractionMode.pointer,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: names,
              builder: (context, names, _) => PregoPickerSearchList(
                searchHint: "Search",
                onQueryChanged: (_) {},
                footer: null,
                rows: [
                  for (final name in names)
                    PregoPickerSearchOption(isSelected: false, onPick: () => picked.add(name), child: Text(name)),
                ],
                emptyText: null,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    names.value = ["first", "second", "third"];
    await tester.pumpAndSettle();
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(picked, ["second"]);

    await tester.enterText(find.byType(TextField), "s");
    names.value = ["first", "second"];
    await tester.pumpAndSettle();
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(picked, ["second", "first"]);
  });
}
