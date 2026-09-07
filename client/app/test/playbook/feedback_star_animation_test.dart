import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

import "feedback_flow_playbook.dart";

void main() {
  testWidgets("only the chosen star bounces without a press circle before advancing", (tester) async {
    await _openRating(tester: tester);
    final star = find.byKey(const ValueKey("rating-3"));
    final button = tester.widget<IconButton>(star);
    expect(tester.getSize(star), const Size(44, 44));
    expect(button.style?.splashFactory, NoSplash.splashFactory);
    expect(button.style?.overlayColor?.resolve({WidgetState.pressed}), Colors.transparent);
    for (var rating = 1; rating <= 5; rating++) {
      expect(_starAsset(tester: tester, rating: rating), "assets/images/feedback_star_default.svg");
    }

    await tester.tap(star);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_scale(tester: tester, rating: 3), lessThan(0.95));
    for (var rating = 1; rating <= 5; rating++) {
      expect(
        _starAsset(tester: tester, rating: rating),
        rating <= 3 ? "assets/images/feedback_star_selected.svg" : "assets/images/feedback_star_default.svg",
      );
    }
    for (final rating in [1, 2, 4, 5]) {
      expect(_scale(tester: tester, rating: rating), 1);
    }

    // A second tap during the bounce must not change the accepted rating.
    await tester.tap(find.byKey(const ValueKey("rating-5")));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scale(tester: tester, rating: 3), greaterThan(1.15));
    expect(_scale(tester: tester, rating: 5), 1);
    expect(find.text("What should we improve?"), findsNothing);

    await tester.pump(const Duration(milliseconds: 120));
    expect(_scale(tester: tester, rating: 3), closeTo(1, 0.02));
    expect(find.text("How’s Sesori working for you?"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    expect(find.text("What should we improve?"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final features in [
    const FakeAccessibilityFeatures(disableAnimations: true),
    const FakeAccessibilityFeatures(reduceMotion: true),
  ]) {
    testWidgets("$features keeps selection feedback without star movement", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _openRating(tester: tester);
      final star = find.byKey(const ValueKey("rating-2"));
      expect(_starAsset(tester: tester, rating: 2), "assets/images/feedback_star_default.svg");

      await tester.tap(star);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_scale(tester: tester, rating: 2), 1);
      expect(_starAsset(tester: tester, rating: 2), "assets/images/feedback_star_selected.svg");

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.text("What should we improve?"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _openRating({required WidgetTester tester}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const FeedbackFlowPlaybook(openOnLaunch: true));
  await tester.pumpAndSettle();
}

double _scale({required WidgetTester tester, required int rating}) => tester
    .widget<Transform>(
      find.descendant(of: find.byKey(ValueKey("rating-$rating")), matching: find.byType(Transform)),
    )
    .transform
    .entry(0, 0);

String _starAsset({required WidgetTester tester, required int rating}) {
  final star = tester.widget<SvgPicture>(
    find.descendant(of: find.byKey(ValueKey("rating-$rating")), matching: find.byType(SvgPicture)),
  );
  return (star.bytesLoader as SvgAssetLoader).assetName;
}
