import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness({required PregoPopoverContentBuilder contentBuilder}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(
      body: Center(
        child: PregoPopover(
          triggerBuilder: (context, toggle) => IconButton(
            onPressed: toggle,
            icon: const Icon(Icons.more_horiz),
          ),
          contentBuilder: contentBuilder,
        ),
      ),
    ),
  );
}

// Free-form content with its own dismiss affordance — the case a menu can't
// express and that motivates PregoPopover over PregoAnchorMenu.
Widget _bodyWithClose(BuildContext context, VoidCallback close) => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text("Popover body"),
      TextButton(onPressed: close, child: const Text("Done")),
    ],
  ),
);

void main() {
  group("Android (flat/cue) path", () {
    testWidgets("opens flat content and closes via the content's close callback", (tester) async {
      await tester.pumpWidget(_harness(contentBuilder: _bodyWithClose));

      // No glass popover is built on Android; content stays hidden until tapped.
      expect(find.byType(GlassPopover), findsNothing);
      expect(find.text("Popover body"), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text("Popover body"), findsOneWidget);

      // The content's own affordance dismisses the bubble via `close`.
      await tester.tap(find.text("Done"));
      await tester.pumpAndSettle();
      expect(find.text("Popover body"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("dismisses on an outside tap", (tester) async {
      await tester.pumpWidget(
        _harness(
          contentBuilder: (context, close) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Tap outside me"),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text("Tap outside me"), findsOneWidget);

      // The transparent barrier closes the popover.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text("Tap outside me"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group("Apple (glass) path", () {
    testWidgets("presents content in a GlassPopover and closes via callback", (tester) async {
      await tester.pumpWidget(_harness(contentBuilder: _bodyWithClose));

      // On Apple platforms the content rides the liquid-glass GlassPopover.
      expect(find.byType(GlassPopover), findsOneWidget);
      expect(find.text("Popover body"), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text("Popover body"), findsOneWidget);

      await tester.tap(find.text("Done"));
      await tester.pumpAndSettle();
      expect(find.text("Popover body"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
