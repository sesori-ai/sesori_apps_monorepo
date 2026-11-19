import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../helpers/trackpad_overscroll.dart";

Widget _app({required PregoInteractionMode mode, required void Function(BuildContext context) onOpen}) {
  return PregoInteractionScope(
    mode: mode,
    child: MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () => onOpen(context), child: const Text("Open")),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open({required WidgetTester tester}) async {
  await tester.tap(find.text("Open"));
  await tester.pumpAndSettle();
}

/// The dialog's visible panel; the [Dialog] widget itself spans the window.
Rect _panel({required WidgetTester tester}) =>
    tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);

/// More buttons than a dialog holds, so the body scrolls.
Widget _buttons() => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var index = 0; index < 20; index++)
      Padding(
        padding: const EdgeInsets.only(bottom: PregoSpacing.sm),
        child: PregoButtonsSolid(
          label: "Option $index",
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.md,
          fullWidth: true,
          onPressed: () {},
        ),
      ),
  ],
);

void main() {
  testWidgets("touch keeps the bottom sheet", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.touch,
        onOpen: (context) =>
            showPregoModal<void>(context: context, title: "Rename", builder: (_) => const Text("Body")),
      ),
    );
    await _open(tester: tester);
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text("Body"), findsOneWidget);
  });

  testWidgets("pointer opens a centred dialog that its close button dismisses", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.pointer,
        onOpen: (context) => showPregoModal<void>(
          context: context,
          title: "Rename",
          builder: (_) => const Text("Body"),
        ),
      ),
    );
    await _open(tester: tester);
    expect(find.byType(PregoBottomSheet), findsNothing);
    expect(find.text("Rename"), findsOneWidget);
    expect(find.text("Body"), findsOneWidget);
    expect(_panel(tester: tester).width, PregoModalWidth.regular.pixels);
    expect(_panel(tester: tester).center, tester.getRect(find.byType(Scaffold)).center);
    // The sheet's surface, so content built for the sheet keeps its contrast.
    expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, PregoDesignSystem.light.colors.bgSecondary);

    await tester.tap(find.byTooltip("Close"));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets("a dialog opened from a dialog stacks, and Esc closes only the top one", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.pointer,
        onOpen: (context) => showPregoModal<void>(
          context: context,
          title: "First",
          builder: (context) => TextButton(
            onPressed: () => showPregoModal<void>(context: context, title: "Second", builder: (_) => const Text("Top")),
            child: const Text("Open second"),
          ),
        ),
      ),
    );
    await _open(tester: tester);
    await tester.tap(find.text("Open second"));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text("Second"), findsNothing);
    expect(find.text("First"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets("a dialog that is not dismissible ignores Esc and the scrim and has no close button", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.pointer,
        onOpen: (context) => showPregoModal<void>(
          context: context,
          title: "Signing in",
          isDismissible: false,
          builder: (_) => const Text("Body"),
        ),
      ),
    );
    await _open(tester: tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byTooltip("Close"), findsNothing);
  });

  testWidgets("reduced motion opens the dialog at once", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.pointer,
        onOpen: (context) =>
            showPregoModal<void>(context: context, title: "Rename", builder: (_) => const Text("Body")),
      ),
    );
    await tester.tap(find.text("Open"));
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(Dialog), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1);
  });

  testWidgets("reduced motion opens the sheet at once", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.touch,
        onOpen: (context) =>
            showPregoModal<void>(context: context, title: "Rename", builder: (_) => const Text("Body")),
      ),
    );
    await tester.tap(find.text("Open"));
    await tester.pump();
    await tester.pump();
    // Already where it settles, not sliding up from the bottom edge.
    final shown = tester.getRect(find.byType(PregoBottomSheet));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PregoBottomSheet)), shown);
  });

  testWidgets("pointer shows the action sheet as a request-wide dialog", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.pointer,
        onOpen: (context) => showPregoModalRoute<void>(
          context: context,
          builder: (_) => const PregoActionSheet(
            title: "Allow this action?",
            topInset: 0,
            actions: Text("Allow once"),
            child: Text("Run make check"),
          ),
        ),
      ),
    );
    await _open(tester: tester);
    expect(_panel(tester: tester).width, PregoModalWidth.request.pixels);
    expect(find.text("Allow this action?"), findsOneWidget);
    expect(find.text("Run make check"), findsOneWidget);
    expect(find.text("Allow once"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets("touch shows a modal surface as the bottom sheet", (tester) async {
    await tester.pumpWidget(
      _app(
        mode: PregoInteractionMode.touch,
        onOpen: (context) => showPregoModalRoute<void>(
          context: context,
          builder: (context) => PregoModalSurface(
            anchorsTop: false,
            title: "Question 1",
            subtitle: "1 of 2",
            onBack: null,
            onClose: () => Navigator.of(context).pop(),
            width: PregoModalWidth.request,
            handleBottomSafeArea: true,
            topInset: 0,
            child: const Text("Body"),
          ),
        ),
      ),
    );
    await _open(tester: tester);
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text("1 of 2"), findsOneWidget);
  });

  testWidgets(
    "a trackpad overscroll stretches a dialog steadily while buttons slide under a resting cursor",
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      await tester.pumpWidget(
        _app(
          mode: PregoInteractionMode.pointer,
          onOpen: (context) => showPregoModal<void>(context: context, title: "Fixture", builder: (_) => _buttons()),
        ),
      );
      await _open(tester: tester);
      await expectSteadyTrackpadOverscroll(tester: tester, target: find.text("Option 19"));
    },
  );

  testWidgets(
    "a trackpad overscroll stretches an action sheet steadily while buttons slide under a resting cursor",
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      await tester.pumpWidget(
        _app(
          mode: PregoInteractionMode.pointer,
          onOpen: (context) => showPregoModalRoute<void>(
            context: context,
            builder: (_) =>
                PregoActionSheet(title: "Fixture", topInset: 0, actions: const Text("Allow"), child: _buttons()),
          ),
        ),
      );
      await _open(tester: tester);
      await expectSteadyTrackpadOverscroll(tester: tester, target: find.text("Option 19"));
    },
  );
}
