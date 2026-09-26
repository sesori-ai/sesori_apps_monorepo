import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Hosts an [AnimationController] and hands it to [builder] so a test can
/// drive the reveal progress directly.
class const _ControllerHost({required final Widget Function(AnimationController controller) builder})
    extends StatefulWidget {
  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState() extends State<_ControllerHost> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(controller);
}

void main() {
  const childKey = Key("row-child");
  const maxReveal = 76.0;

  Future<AnimationController> pumpReveal(WidgetTester tester, {required int? createdAtMs}) async {
    late AnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _ControllerHost(
            builder: (c) {
              controller = c;
              return MessageTimestampReveal(
                progress: c,
                maxReveal: maxReveal,
                createdAtMs: createdAtMs,
                child: const SizedBox(key: childKey, width: 200, height: 40),
              );
            },
          ),
        ),
      ),
    );
    return controller;
  }

  double childTranslationX(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.ancestor(of: find.byKey(childKey), matching: find.byType(Transform)).first,
    );
    return transform.transform.getTranslation().x;
  }

  double gutterRight(WidgetTester tester) {
    return tester.widget<Positioned>(find.byType(Positioned)).right!;
  }

  testWidgets("keeps content in place and paints no gutter while closed", (tester) async {
    await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);

    expect(childTranslationX(tester), 0);
    // The gutter is unclipped, so a closed row must build none at all rather
    // than park a label one width out in a wide pane's empty side margin.
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets("slides content left and the gutter flush when fully revealed", (tester) async {
    final controller = await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);

    controller.value = 1;
    await tester.pump();

    expect(childTranslationX(tester), -maxReveal);
    expect(gutterRight(tester), 0);
  });

  testWidgets("tracks partial progress proportionally", (tester) async {
    final controller = await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);

    controller.value = 0.5;
    await tester.pump();

    expect(childTranslationX(tester), -maxReveal / 2);
    expect(gutterRight(tester), -maxReveal / 2);
  });

  testWidgets("renders a timestamp label when a creation time is present", (tester) async {
    final controller = await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);
    controller.value = 1;
    await tester.pump();

    expect(
      find.descendant(of: find.byType(MessageTimestampReveal), matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets("renders no gutter when the row has no timestamp", (tester) async {
    await pumpReveal(tester, createdAtMs: null);

    expect(find.byType(Positioned), findsNothing);
    expect(find.descendant(of: find.byType(MessageTimestampReveal), matching: find.byType(Text)), findsNothing);
    // Still wraps the row so it slides with the rest of the transcript.
    expect(childTranslationX(tester), 0);
  });

  /// Pumps rows of the given content widths inside a [columnWidth] reading
  /// column, each wrapped the way the transcript wraps its rows — an
  /// `Align(widthFactor: 1)`, which loosens the width constraint — and reveals
  /// them fully.
  Future<void> pumpColumn(
    WidgetTester tester, {
    required double columnWidth,
    required List<double> contentWidths,
  }) async {
    late AnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: columnWidth,
              child: _ControllerHost(
                builder: (c) {
                  controller = c;
                  return Column(
                    children: [
                      for (final width in contentWidths)
                        Align(
                          alignment: AlignmentDirectional.topStart,
                          widthFactor: 1,
                          heightFactor: 1,
                          child: MessageTimestampReveal(
                            progress: c,
                            maxReveal: maxReveal,
                            createdAtMs: DateTime.utc(2026, 9, 26, 16, 46).millisecondsSinceEpoch,
                            child: SizedBox(key: ValueKey("row-$width"), width: width, height: 40),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    controller.value = 1;
    await tester.pump();
  }

  Rect labelRect(WidgetTester tester, {required double contentWidth}) {
    final row = find.ancestor(
      of: find.byKey(ValueKey("row-$contentWidth")),
      matching: find.byType(MessageTimestampReveal),
    );
    final label = tester.renderObject<RenderBox>(find.descendant(of: row, matching: find.byType(Text)));
    return label.localToGlobal(Offset.zero) & label.size;
  }

  testWidgets("reveals every row on one alignment line whatever the row's own width", (tester) async {
    // A narrow tool row, a mid-width assistant paragraph and a row that fills
    // the reading column: the transcript's rows shrink-wrap their content, and
    // the gutter must not follow them.
    const contentWidths = [120.0, 400.0, 760.0];
    await pumpColumn(tester, columnWidth: 760, contentWidths: contentWidths);

    final lefts = contentWidths.map((width) => labelRect(tester, contentWidth: width).left).toSet();
    expect(lefts, hasLength(1));
  });

  testWidgets("keeps a settled reveal inside the narrowest supported window", (tester) async {
    // The desktop window minimum is 560 wide, where the reading column fills
    // the pane and leaves the gutter no margin to spill into.
    const windowWidth = 560.0;
    tester.view.physicalSize = const Size(windowWidth, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpColumn(tester, columnWidth: windowWidth, contentWidths: const [120.0, windowWidth]);

    for (final width in const [120.0, windowWidth]) {
      final rect = labelRect(tester, contentWidth: width);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(windowWidth));
    }
  });
}
