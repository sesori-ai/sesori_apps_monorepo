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
          showLabel: true,
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

  testWidgets("without its label the pill keeps only the glyph and names itself", (tester) async {
    await tester.pumpWidget(
      _harness(
        SizedBox(
          width: 44,
          child: PregoPickerButton(
            leadingIcon: TablerRegular.robot,
            label: "Agent",
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            onPressed: () {},
            showLabel: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text("Agent"), findsNothing);
    expect(find.byIcon(TablerRegular.selector), findsNothing);
    expect(find.byIcon(TablerRegular.robot), findsOneWidget);
    expect(find.bySemanticsLabel("Agent"), findsOneWidget);
  });

  testWidgets("without onPressed the pill only shows its value", (tester) async {
    Widget pill({required bool showLabel}) => _harness(
      SizedBox(
        width: showLabel ? 200 : 44,
        child: PregoPickerButton(
          leadingIcon: TablerRegular.cpu,
          label: "Model",
          surfaceStyle: PregoComposerSurfaceStyle.subtle,
          onPressed: null,
          showLabel: showLabel,
        ),
      ),
    );

    await tester.pumpWidget(pill(showLabel: true));
    expect(find.text("Model"), findsOneWidget);
    // No caret and no press feedback: there is nothing to open.
    expect(find.byIcon(TablerRegular.selector), findsNothing);
    expect(find.byType(InkWell), findsNothing);

    await tester.pumpWidget(pill(showLabel: false));
    expect(tester.getSemantics(find.bySemanticsLabel("Model")), isSemantics(label: "Model", isButton: false));
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
            showLabel: true,
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
                showLabel: true,
              ),
            ),
          ],
        ),
      ),
    );

    // No overflow error: the label keeps its end on one line inside the pill.
    expect(tester.takeException(), isNull);
    expect(find.byType(PregoEllipsisText), findsOneWidget);
    expect(
      tester.getRect(find.byType(PregoEllipsisText)).right,
      lessThanOrEqualTo(tester.getRect(find.byType(PregoPickerButton)).right),
    );
  });
}
