import "package:cupertino_ui/cupertino_ui.dart" show CupertinoDatePicker, CupertinoDatePickerMode;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

Widget _app({required PregoInteractionMode mode, required Widget field}) => PregoInteractionScope(
  mode: mode,
  child: MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: PregoGroupedRows(children: [field])),
  ),
);

void main() {
  final value = DateTime(2026, 11, 17, 9);

  PregoDateTimeField field({
    required PregoDateTimeFieldMode mode,
    required DateTime? minimum,
    required ValueChanged<DateTime> onChanged,
  }) => PregoDateTimeField(
    icon: null,
    label: "Time",
    valueLabel: "9:00 AM",
    value: value,
    mode: mode,
    minimum: minimum,
    onChanged: onChanged,
  );

  testWidgets("shows its value and opens a time wheel in a sheet on touch", (tester) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.touch,
        field: field(mode: PregoDateTimeFieldMode.time, minimum: null, onChanged: picked.add),
      ),
    );

    expect(find.text("9:00 AM"), findsOneWidget);
    await tester.tap(find.text("Time"));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.mode, CupertinoDatePickerMode.time);
    expect(picker.initialDateTime, value);
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(picked, isEmpty);

    picker.onDateTimeChanged(DateTime(2026, 11, 17, 10, 15));
    expect(picked, [DateTime(2026, 11, 17, 10, 15)]);
  });

  testWidgets("opens in a dialog under a pointer", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.pointer,
        field: field(mode: PregoDateTimeFieldMode.dateAndTime, minimum: null, onChanged: (_) {}),
      ),
    );

    await tester.tap(find.text("Time"));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).mode,
      CupertinoDatePickerMode.dateAndTime,
    );
  });

  testWidgets("never offers a moment before the minimum, and moves a passed value onto it", (tester) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.touch,
        field: field(
          mode: PregoDateTimeFieldMode.dateAndTime,
          minimum: DateTime(2026, 11, 17, 9, 30, 20),
          onChanged: picked.add,
        ),
      ),
    );

    await tester.tap(find.text("Time"));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.minimumDate, DateTime(2026, 11, 17, 9, 31));
    expect(picker.initialDateTime, DateTime(2026, 11, 17, 9, 31));
    expect(picked, [DateTime(2026, 11, 17, 9, 31)]);
  });
}
