import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/navigation/prego_top_bar_inset.dart"
    show PregoRootTopBarInsetOwner, clearPregoRootTopBarInset, pregoRootTopBarInsetFor, publishPregoRootTopBarInset;
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("root top-bar inset retains and restores mounted scaffold order", (tester) async {
    late OverlayState overlay;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            overlay = Overlay.of(context, rootOverlay: true);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final underlying = PregoRootTopBarInsetOwner();
    final topmost = PregoRootTopBarInsetOwner();

    publishPregoRootTopBarInset(overlay: overlay, owner: underlying, inset: 70);
    publishPregoRootTopBarInset(overlay: overlay, owner: topmost, inset: 90);
    publishPregoRootTopBarInset(overlay: overlay, owner: underlying, inset: 80);
    expect(pregoRootTopBarInsetFor(overlay), 90);

    clearPregoRootTopBarInset(overlay: overlay, owner: topmost);
    expect(pregoRootTopBarInsetFor(overlay), 80);
    clearPregoRootTopBarInset(overlay: overlay, owner: underlying);
    expect(pregoRootTopBarInsetFor(overlay), isNull);
  });

  testWidgets("renders each visual variant and optional content", (tester) async {
    for (final variant in PregoPopupAlertsNotificationsVariant.values) {
      await tester.pumpWidget(
        _harness(
          PregoPopupAlertsNotifications(
            title: variant.name,
            message: "Supporting text",
            variant: variant,
            primaryAction: PregoPopupAlertsNotificationsAction(label: "Primary", onPressed: () {}),
            secondaryAction: PregoPopupAlertsNotificationsAction(label: "Secondary", onPressed: () {}),
            onClose: () {},
          ),
        ),
      );

      expect(find.text(variant.name), findsOneWidget);
      expect(find.text("Supporting text"), findsOneWidget);
      expect(find.text("Primary"), findsOneWidget);
      expect(find.text("Secondary"), findsOneWidget);
      expect(find.bySemanticsLabel("Close notification"), findsOneWidget);
    }
  });

  testWidgets("keeps text contrast on its dark surface in light appearance", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: const Scaffold(
          body: PregoPopupAlertsNotifications(
            title: "Title",
            message: "Supporting text",
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.text("Title")).style?.color, PregoDesignSystem.dark.colors.textPrimary);
    expect(
      tester.widget<Text>(find.text("Supporting text")).style?.color,
      PregoDesignSystem.dark.colors.textSecondary,
    );
  });

  testWidgets("keeps the close icon 16 pixels from the text and trailing edge", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    presenter.show(title: "Sessions updated", duration: null);
    await tester.pumpAndSettle();

    final cardRight = tester.getTopRight(find.byType(PregoPopupAlertsNotifications)).dx;
    final textRight = tester.getTopRight(find.text("Sessions updated")).dx;
    final iconLeft = tester.getTopLeft(find.byIcon(TablerRegular.x)).dx;
    final iconRight = tester.getTopRight(find.byIcon(TablerRegular.x)).dx;

    expect(iconLeft - textRight, PregoSpacing.xl);
    expect(cardRight - iconRight, PregoSpacing.xl);
  });

  testWidgets("uses Figma's shallow lower-edge accent gradient", (tester) async {
    await tester.pumpWidget(
      _harness(
        const PregoPopupAlertsNotifications(
          title: "Accepted",
          variant: PregoPopupAlertsNotificationsVariant.success,
        ),
      ),
    );

    final gradient = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<RadialGradient>()
        .single;

    expect(gradient.center, const Alignment(0, -0.885));
    expect(gradient.radius, 0.94);
    expect(gradient.transform, isNotNull);
    expect(gradient.colors, [
      const Color(0x08FFFFFF),
      PregoDesignSystem.dark.colors.fgSuccessSecondary.withValues(alpha: 0.30),
    ]);
  });

  testWidgets("presenter places the alert below navigation and auto dismisses", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    presenter.show(title: "Copied");
    await tester.pumpAndSettle();

    expect(find.text("Copied"), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(PregoPopupAlertsNotifications)).dy,
      PregoTopNavigation.barHeight + PregoSpacing.xl,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text("Copied"), findsNothing);
  });

  testWidgets("swiping up dismisses the alert before its duration elapses", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    presenter.show(title: "Session deleted");
    await tester.pumpAndSettle();

    await tester.fling(find.text("Session deleted"), const Offset(0, -200), 1000);
    await tester.pumpAndSettle();

    expect(find.text("Session deleted"), findsNothing);
  });

  testWidgets("enters from above and exits upward with a fast start", (tester) async {
    final presenter = await _pumpPresenter(tester: tester);
    presenter.show(title: "Motion", duration: null);
    await tester.pump();

    final card = find.byType(PregoPopupAlertsNotifications);
    final fade = tester.widget<FadeTransition>(find.ancestor(of: card, matching: find.byType(FadeTransition)).first);
    final scale = tester.widget<ScaleTransition>(find.ancestor(of: card, matching: find.byType(ScaleTransition)).first);
    const top = PregoTopNavigation.barHeight + PregoSpacing.xl;
    expect(fade.opacity.value, 0);
    expect(scale.scale.value, 0.96);
    expect(scale.alignment, Alignment.topCenter);
    expect(tester.getTopLeft(card).dy, lessThan(top));

    await tester.pump(const Duration(milliseconds: 50));
    expect(fade.opacity.value, inExclusiveRange(0.5, 1));
    expect(tester.getTopLeft(card).dy, lessThan(top));
    await tester.pump(const Duration(milliseconds: 170));
    expect(fade.opacity.value, 1);
    expect(scale.scale.value, 1);
    expect(tester.getTopLeft(card).dy, top);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    presenter.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(fade.opacity.value, inExclusiveRange(0, 0.5));
    expect(scale.scale.value, inExclusiveRange(0.96, 1));
    expect(tester.getTopLeft(card).dy, lessThan(top));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets("closing during entrance continues from the painted position", (tester) async {
    final presenter = await _pumpPresenter(tester: tester);
    presenter.show(title: "Interrupted", duration: null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));

    final card = find.byType(PregoPopupAlertsNotifications);
    final fade = tester.widget<FadeTransition>(find.ancestor(of: card, matching: find.byType(FadeTransition)).first);
    final opacity = fade.opacity.value;
    final position = tester.getTopLeft(card);
    presenter.dismiss();
    await tester.pump();
    expect(fade.opacity.value, opacity);
    expect(tester.getTopLeft(card), position);

    await tester.pump(const Duration(milliseconds: 15));
    expect(fade.opacity.value, lessThan(opacity));
    expect(tester.getTopLeft(card).dy, lessThan(position.dy));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (name, feature) in [
    ("Android Remove animations", const FakeAccessibilityFeatures(disableAnimations: true)),
    ("iOS Reduce Motion", const FakeAccessibilityFeatures(reduceMotion: true)),
  ]) {
    testWidgets("$name fades without automatic movement and retains swipe dismissal", (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = feature;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final presenter = await _pumpPresenter(tester: tester);
      presenter.show(title: "Reduced motion", duration: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final card = find.byType(PregoPopupAlertsNotifications);
      final fade = tester.widget<FadeTransition>(find.ancestor(of: card, matching: find.byType(FadeTransition)).first);
      final scale = tester.widget<ScaleTransition>(
        find.ancestor(of: card, matching: find.byType(ScaleTransition)).first,
      );
      const top = PregoTopNavigation.barHeight + PregoSpacing.xl;
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(scale.scale.value, 1);
      expect(tester.getTopLeft(card).dy, top);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel("Close notification"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(tester.getTopLeft(card).dy, top);
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      presenter.show(title: "Swipe only", duration: null, showCloseButton: false);
      await tester.pumpAndSettle();
      await tester.fling(find.text("Swipe only"), const Offset(0, -200), 1000);
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });
  }

  testWidgets("reacts to iOS Reduce Motion changing during entrance and exit", (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final presenter = await _pumpPresenter(tester: tester);
    presenter.show(title: "Preference change", duration: null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final card = find.byType(PregoPopupAlertsNotifications);
    const top = PregoTopNavigation.barHeight + PregoSpacing.xl;
    expect(tester.getTopLeft(card).dy, lessThan(top));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(tester.getTopLeft(card).dy, top);
    await tester.pumpAndSettle();

    presenter.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getTopLeft(card).dy, top);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.pump();
    expect(tester.getTopLeft(card).dy, lessThan(top));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("announces presented feedback as a live region", (tester) async {
    final semantics = tester.ensureSemantics();
    final presenter = await _pumpPresenter(tester: tester);
    presenter.show(title: "Feedback sent", duration: null);
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.text("Feedback sent")).flagsCollection.isLiveRegion, isTrue);
    expect(find.bySemanticsLabel("Close notification"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("sizes to short text and caps long text at 16 pixel side insets", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    presenter.show(title: "Copied", duration: null);
    await tester.pumpAndSettle();
    final shortWidth = tester.getSize(find.byType(PregoPopupAlertsNotifications)).width;
    final shortTextHeight = tester.getSize(find.text("Copied")).height;

    const longTitle =
        "This popup has enough text to reach the available width and then continue naturally onto another line";
    presenter.show(title: longTitle, duration: null);
    await tester.pumpAndSettle();

    expect(shortWidth, lessThan(800 - 2 * PregoSpacing.xl));
    expect(tester.getSize(find.byType(PregoPopupAlertsNotifications)).width, 800 - 2 * PregoSpacing.xl);
    expect(tester.getSize(find.text(longTitle)).height, greaterThan(shortTextHeight));
  });

  testWidgets("keeps action-bearing alerts sized to their content", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    presenter.show(
      title: "Saved",
      content: PregoPopupAlertContent(
        message: "Your changes were saved successfully",
        primaryAction: PregoPopupAlertsNotificationsAction(label: "Open", onPressed: () {}),
      ),
      duration: null,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(PregoPopupAlertsNotifications)).width,
      lessThan(800 - 2 * PregoSpacing.xl),
    );
    final contentRight = tester.getTopRight(find.text("Your changes were saved successfully")).dx;
    final buttonRight = tester
        .getTopRight(find.ancestor(of: find.text("Open"), matching: find.byType(Semantics)).first)
        .dx;
    expect(buttonRight, contentRight);
  });

  testWidgets("uses overlay status-bar padding when a modal strips its top padding", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.dark]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 24)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
              child: Builder(
                builder: (modalContext) {
                  presenter = PregoPopupAlertPresenter.of(modalContext);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );

    presenter.show(title: "Modal alert", duration: null);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(PregoPopupAlertsNotifications)).dy,
      24 + PregoTopNavigation.barHeight + PregoSpacing.xl,
    );
  });

  testWidgets("new alerts replace old alerts and close immediately on tap", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    presenter.show(title: "First", duration: null);
    await tester.pumpAndSettle();
    presenter.show(title: "Second", duration: null);
    await tester.pumpAndSettle();

    expect(find.text("First"), findsNothing);
    expect(find.text("Second"), findsOneWidget);

    await tester.tap(find.bySemanticsLabel("Close notification"));
    await tester.pumpAndSettle();
    expect(find.text("Second"), findsNothing);
  });

  testWidgets("replacement remains safe while the first alert is dismissing", (tester) async {
    late PregoPopupAlertPresenter presenter;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) {
            presenter = PregoPopupAlertPresenter.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    presenter.show(title: "First", duration: null);
    await tester.pumpAndSettle();
    presenter.dismiss();
    await tester.pump(const Duration(milliseconds: 40));
    presenter.show(title: "Second", duration: null);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("First"), findsNothing);
    expect(find.text("Second"), findsOneWidget);
  });

  testWidgets("tracks the live top-bar banner inset", (tester) async {
    late BuildContext presentationContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.dark]),
        home: PregoGlassScaffold(
          title: "Screen",
          banner: const SizedBox(height: 30),
          slivers: [
            SliverFillRemaining(
              child: Builder(
                builder: (context) {
                  presentationContext = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final presenter = PregoPopupAlertPresenter.of(presentationContext);
    presenter.show(title: "Below banner", duration: null);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(PregoPopupAlertsNotifications)).dy,
      PregoTopNavigation.barHeight + 30 + PregoSpacing.xl,
    );
  });

  testWidgets("explicit-overlay presenter clears the active scaffold banner", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.dark]),
        home: const PregoGlassScaffold(
          title: "Screen",
          banner: SizedBox(height: 30),
          slivers: [SliverFillRemaining(child: SizedBox.expand())],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final presenter = PregoPopupAlertPresenter.fromOverlayState(
      tester.state<OverlayState>(find.byType(Overlay).first),
    );
    presenter.show(title: "Below banner", duration: null);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(PregoPopupAlertsNotifications)).dy,
      PregoTopNavigation.barHeight + 30 + PregoSpacing.xl,
    );
  });
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.dark]),
    home: Scaffold(body: child),
  );
}

Future<PregoPopupAlertPresenter> _pumpPresenter({required WidgetTester tester}) async {
  late PregoPopupAlertPresenter presenter;
  await tester.pumpWidget(
    _harness(
      Builder(
        builder: (context) {
          presenter = PregoPopupAlertPresenter.of(context);
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return presenter;
}
