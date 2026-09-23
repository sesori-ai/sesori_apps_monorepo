import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets("renders leading icon, label, caret, and routes taps", (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        PregoPickerButton(
          leadingIcon: TablerRegular.robot,
          label: "Agent",
          surfaceStyle: PregoComposerSurfaceStyle.subtle,
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.text("Agent"), findsOneWidget);
    expect(find.byIcon(TablerRegular.robot), findsOneWidget);
    // The trailing caret signals the pill opens a menu.
    expect(find.byIcon(TablerRegular.selector), findsOneWidget);

    await tester.tap(find.byType(PregoPickerButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets(
    "uses the composer surface and Material interaction on both platforms",
    (tester) async {
      await tester.pumpWidget(
        _harness(
          PregoPickerButton(
            leadingIcon: TablerRegular.cpu,
            label: "Model",
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(PregoPickerButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();
      final surface = decorations.singleWhere(
        (decoration) => decoration.color == PregoColorsLight.bgSurface2,
      );
      expect(surface.border, Border.all(color: PregoColorsLight.borderSecondary));
      expect(
        surface.boxShadow,
        [
          const BoxShadow(
            color: PregoColorsLight.shadowXs,
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets("ellipsizes a long label instead of overflowing", (tester) async {
    await tester.pumpWidget(
      _harness(
        Row(
          children: [
            Expanded(
              child: PregoPickerButton(
                leadingIcon: TablerRegular.cpu,
                label: "An extremely long model name that cannot possibly fit in one pill" * 3,
                surfaceStyle: PregoComposerSurfaceStyle.subtle,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );

    // No overflow error: the label keeps its end on one line inside the pill.
    expect(tester.takeException(), isNull);
    expect(find.byType(PregoStartEllipsisText), findsOneWidget);
    expect(
      tester.getRect(find.byType(PregoStartEllipsisText)).right,
      lessThanOrEqualTo(tester.getRect(find.byType(PregoPickerButton)).right),
    );
  });
}
