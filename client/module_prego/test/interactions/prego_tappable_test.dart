import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness({required Widget child, bool disableAnimations = false}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _button({required VoidCallback? onTap}) {
  return PregoTappable.stateAware(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    childBuilder: ({required Set<WidgetState> state}) => SizedBox(
      width: 100,
      height: 44,
      child: Center(child: Text(state.contains(WidgetState.disabled) ? "Disabled" : "Ready")),
    ),
    containerBuilder: ({required Widget child, required Set<WidgetState> state}) => ColoredBox(
      key: const ValueKey("press-fill"),
      color: state.contains(WidgetState.pressed) ? Colors.blue : Colors.transparent,
      child: child,
    ),
  );
}

double _scale({required WidgetTester tester}) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(PregoTappable), matching: find.byType(Transform)).first,
  );
  return transform.transform.entry(0, 0);
}

Color _pressColor({required WidgetTester tester}) =>
    tester.widget<ColoredBox>(find.byKey(const ValueKey("press-fill"))).color;

void main() {
  testWidgets("iOS loading preserves the active press until it settles at rest", (tester) async {
    var loading = false;
    var calls = 0;
    await tester.pumpWidget(
      _harness(
        child: StatefulBuilder(
          builder: (context, setState) => PregoButtonsSolid(
            label: "Send",
            hierarchy: .primary,
            size: .md,
            isLoading: loading,
            onPressed: () => setState(() {
              calls++;
              loading = true;
            }),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PregoTappable)));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 300));
    final heldScale = _scale(tester: tester);
    expect(heldScale, greaterThan(1));

    await gesture.up();
    await tester.pump();
    expect(calls, 1);
    expect(loading, isTrue);
    expect(_scale(tester: tester), moreOrLessEquals(heldScale));

    await tester.pump(const Duration(milliseconds: 75));
    expect(_scale(tester: tester), greaterThan(1));
    expect(_scale(tester: tester), lessThan(heldScale));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scale(tester: tester), 1);

    await tester.tap(find.byType(PregoTappable));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets("disabling a held iOS control cancels the press and remains inert", (tester) async {
    var calls = 0;
    void onTap() => calls++;
    await tester.pumpWidget(_harness(child: _button(onTap: onTap)));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PregoTappable)));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scale(tester: tester), greaterThan(1));

    await tester.pumpWidget(_harness(child: _button(onTap: null)));
    expect(find.text("Disabled"), findsOneWidget);
    expect(_pressColor(tester: tester), Colors.transparent);
    await tester.pump(const Duration(milliseconds: 160));
    await gesture.up();
    await tester.pump();
    expect(_scale(tester: tester), 1);
    expect(calls, 0);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_harness(child: _button(onTap: onTap)));
    await tester.tap(find.byType(PregoTappable));
    await tester.pumpAndSettle();
    expect(find.text("Ready"), findsOneWidget);
    expect(calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final useIosPreference in [true, false]) {
    testWidgets(
      "${useIosPreference ? 'iOS Reduce Motion' : 'MediaQuery disableAnimations'} keeps static press feedback",
      (tester) async {
        if (useIosPreference) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            reduceMotion: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        var calls = 0;
        await tester.pumpWidget(
          _harness(
            disableAnimations: !useIosPreference,
            child: _button(onTap: () => calls++),
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(find.byType(PregoTappable)));
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pump(const Duration(milliseconds: 160));
        expect(_scale(tester: tester), 1);
        expect(_pressColor(tester: tester), Colors.blue);
        expect(tester.hasRunningAnimations, isFalse);

        await gesture.up();
        await tester.pump();
        expect(calls, 1);
        expect(_scale(tester: tester), 1);
        expect(_pressColor(tester: tester), Colors.transparent);
        expect(tester.hasRunningAnimations, isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets("enabling Reduce Motion mid-release cancels its continuation", (tester) async {
    await tester.pumpWidget(_harness(child: _button(onTap: () {})));
    await tester.tap(find.byType(PregoTappable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_scale(tester: tester), greaterThan(1));

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      reduceMotion: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(_scale(tester: tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scale(tester: tester), 1);
    expect(tester.hasRunningAnimations, isFalse);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PregoTappable)));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_scale(tester: tester), greaterThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets("non-iOS disabled controls stay static and enabled taps activate", (tester) async {
    await tester.pumpWidget(_harness(child: _button(onTap: null)));
    expect(find.text("Disabled"), findsOneWidget);
    expect(find.descendant(of: find.byType(PregoTappable), matching: find.byType(GestureDetector)), findsNothing);
    expect(find.descendant(of: find.byType(PregoTappable), matching: find.byType(Transform)), findsNothing);

    var calls = 0;
    await tester.pumpWidget(_harness(child: _button(onTap: () => calls++)));
    await tester.tap(find.byType(PregoTappable));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.descendant(of: find.byType(PregoTappable), matching: find.byType(Transform)), findsNothing);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.macOS}));
}
