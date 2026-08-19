import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("uses iOS press motion when the effective theme platform is iOS", (tester) async {
    await tester.pumpWidget(_testApp(platform: TargetPlatform.iOS));

    expect(find.byType(InkWell), findsNothing);

    final transformFinder = find.ancestor(
      of: find.byKey(_targetKey),
      matching: find.byType(Transform),
    );
    expect(transformFinder, findsOneWidget);
    expect(tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(), 1);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_targetKey)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.widget<Transform>(transformFinder).transform.getMaxScaleOnAxis(), greaterThan(1));

    await gesture.up();
  });

  testWidgets("uses Android ripple when the effective theme platform is Android", (tester) async {
    await tester.pumpWidget(_testApp(platform: TargetPlatform.android));

    expect(find.byType(InkWell), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(_targetKey),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}

const _targetKey = Key("prego-tappable-test-target");

Widget _testApp({required TargetPlatform platform}) => MaterialApp(
  theme: ThemeData(
    platform: platform,
    extensions: [PregoDesignSystem.light],
  ),
  home: Scaffold(
    body: Center(
      child: PregoTappable(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        containerBuilder: (child) => SizedBox(
          key: _targetKey,
          width: 120,
          height: 44,
          child: child,
        ),
        child: const Text("Continue"),
      ),
    ),
  ),
);
