import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness({required String message}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(
      body: Center(
        child: PregoInfoPopover(
          message: message,
          triggerBuilder: (context, toggle) => IconButton(
            onPressed: toggle,
            icon: const Icon(Icons.info_outline),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const message = "This adds the Sesori bridge command to your machine.";

  group("Android (flat/cue) path", () {
    testWidgets("reveals the message on tap and dismisses on an outside tap", (tester) async {
      await tester.pumpWidget(_harness(message: message));

      // No glass popover is built on Android, and the message stays hidden until
      // the trigger is tapped.
      expect(find.byType(GlassPopover), findsNothing);
      expect(find.text(message), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);

      // Tapping the transparent barrier (away from the bubble) dismisses it —
      // the popover is purely informational, so there is nothing to select.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group("Apple (glass) path", () {
    testWidgets("presents the message inside a glass popover", (tester) async {
      await tester.pumpWidget(_harness(message: message));

      // On Apple platforms the popover rides the liquid-glass GlassPopover.
      expect(find.byType(GlassPopover), findsOneWidget);
      expect(find.text(message), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
