import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

void main() {
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
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.dark]),
    home: Scaffold(body: child),
  );
}
