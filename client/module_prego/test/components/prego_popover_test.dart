import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
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

// PregoPopover renders the same flat, `cue`-sprung Material bubble on every
// platform, so the behaviour is asserted across both Android and Apple.
const _everyPlatform = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

void main() {
  testWidgets("opens flat content and closes via the content's close callback", (tester) async {
    await tester.pumpWidget(_harness(contentBuilder: _bodyWithClose));

    // Content stays hidden until the trigger is tapped.
    expect(find.text("Popover body"), findsNothing);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text("Popover body"), findsOneWidget);

    // The content's own affordance dismisses the bubble via `close`.
    await tester.tap(find.text("Done"));
    await tester.pumpAndSettle();
    expect(find.text("Popover body"), findsNothing);
  }, variant: _everyPlatform);

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
  }, variant: _everyPlatform);
}
