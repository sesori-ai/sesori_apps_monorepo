import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget app({required Brightness brightness, required Widget alert}) {
    return MaterialApp(
      theme: buildPregoThemeData(brightness: brightness),
      home: Scaffold(body: alert),
    );
  }

  Finder card() => find
      .descendant(
        of: find.byType(PregoInlineAlertsNotifications),
        matching: find.byType(Material),
      )
      .first;

  Finder surface() => find
      .descendant(
        of: find.byType(PregoInlineAlertsNotifications),
        matching: find.byType(DecoratedBox),
      )
      .first;

  for (final brightness in Brightness.values) {
    final design = brightness == Brightness.dark ? PregoDesignSystem.dark : PregoDesignSystem.light;

    testWidgets("inline alerts have inset rounded surfaces in $brightness", (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 956));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final type in PregoInlineAlertsNotificationsType.values) {
        await tester.pumpWidget(
          app(
            brightness: brightness,
            alert: PregoInlineAlertsNotifications(title: "Bridge disconnected", type: type),
          ),
        );

        final bounds = tester.getRect(card());
        expect(bounds.left, PregoSpacing.xl);
        expect(bounds.right, 440 - PregoSpacing.xl);
        expect(bounds.top, PregoSpacing.xl);
        expect(tester.getRect(find.byType(PregoInlineAlertsNotifications)).bottom - bounds.bottom, PregoSpacing.xl);
        final material = tester.widget<Material>(card());
        expect(material.type, MaterialType.transparency);
        expect(material.clipBehavior, Clip.antiAlias);
        expect(material.borderRadius, BorderRadius.circular(PregoRadius.x2l));
        expect(material.shape, isNull);
        final decoration = tester.widget<DecoratedBox>(surface()).decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(PregoRadius.x2l));
        expect(decoration.border, Border.all(color: design.colors.borderPrimary));
        final gradient = decoration.gradient! as RadialGradient;
        expect(gradient.colors.first, design.colors.bgSurface5);
        expect(gradient.colors.every((color) => color.a == 1), isTrue);
        final title = tester.widget<Text>(find.text("Bridge disconnected"));
        expect(title.style?.color, design.colors.textPrimary);
        expect(title.style?.fontWeight, FontWeight.w500);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets("warning content matches Figma spacing and tint in $brightness", (tester) async {
      await tester.pumpWidget(
        app(
          brightness: brightness,
          alert: const PregoInlineAlertsNotifications(
            title: "Bridge disconnected",
            type: PregoInlineAlertsNotificationsType.warning,
            icon: TablerRegular.broadcast_off,
          ),
        ),
      );

      final bounds = tester.getRect(card());
      final icon = tester.getRect(find.byIcon(TablerRegular.broadcast_off));
      expect(bounds.height, 54);
      expect(icon.left - bounds.left, PregoSpacing.xl);
      expect(icon.top - bounds.top, PregoSpacing.xl);
      expect(tester.getTopLeft(find.text("Bridge disconnected")).dx - icon.right, PregoSpacing.sm);
      final decoration = tester.widget<DecoratedBox>(surface()).decoration as BoxDecoration;
      // The rounded fill and border live outside the ink/content clip. Keeping
      // the gradient inside Material reintroduces clipped-edge artifacts.
      expect(find.descendant(of: card(), matching: surface()), findsNothing);
      expect(tester.getRect(surface()), bounds);
      final gradient = decoration.gradient! as RadialGradient;
      expect(gradient.colors, [
        design.colors.bgSurface5,
        Color.alphaBlend(design.colors.bgWarningSecondary.withValues(alpha: 0.2), design.colors.bgSurface5),
      ]);
      expect(gradient.stops, [0.6, 1.0]);
    });

    testWidgets("loading indicator follows the card's $brightness palette", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          app(
            brightness: brightness,
            alert: const PregoInlineAlertsNotifications(
              title: "Loading",
              type: PregoInlineAlertsNotificationsType.loading,
            ),
          ),
        );
        expect(tester.widget<PregoActivityIndicator>(find.byType(PregoActivityIndicator)).color, isNull);
        expect(
          tester.widget<PregoSteppedActivityIndicator>(find.byType(PregoSteppedActivityIndicator)).color,
          PregoActivityIndicator.naturalColor(brightness: brightness),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets("supporting content and alert actions remain usable in $brightness", (tester) async {
      var primaryCalls = 0;
      var secondaryCalls = 0;
      var closeCalls = 0;
      await tester.pumpWidget(
        app(
          brightness: brightness,
          alert: PregoInlineAlertsNotifications(
            title: "Alert",
            supportingText: "Supporting text",
            additionalContent: const Text("Additional content"),
            primaryAction: PregoInlineAlertsNotificationsAction(label: "Retry", onPressed: () => primaryCalls++),
            secondaryAction: PregoInlineAlertsNotificationsAction(label: "Details", onPressed: () => secondaryCalls++),
            onClose: () => closeCalls++,
          ),
        ),
      );

      final supporting = tester.widget<Text>(find.text("Supporting text"));
      expect(supporting.style?.color, design.colors.textSecondary);
      expect(find.text("Additional content"), findsOneWidget);
      final actionContext = tester.element(find.text("Details"));
      expect(actionContext.prego.colors.brightness, brightness);
      await tester.tap(find.text("Retry"));
      await tester.tap(find.text("Details"));
      await tester.tap(find.byIcon(TablerRegular.x));
      expect((primaryCalls, secondaryCalls, closeCalls), (1, 1, 1));
      expect(tester.takeException(), isNull);
    });
  }
}
