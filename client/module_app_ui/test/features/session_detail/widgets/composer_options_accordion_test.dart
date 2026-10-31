import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/composer_options_accordion.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

/// The composer's labelled buttons keep their tooltip's words off the semantics
/// tree, which is what `find.byTooltip` reads.
Finder _tooltip(String message) => find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == message);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("${brightness.name}: actions replace the opener and collapse after selection", (tester) async {
      var attachmentPicks = 0;
      var commandPicks = 0;
      await _pumpAccordion(
        tester: tester,
        brightness: brightness,
        alwaysOpen: false,
        actionsEnabled: true,
        showAttachImage: true,
        onAttachImageTap: () => attachmentPicks++,
        onSlashCommandsTap: () => commandPicks++,
      );

      final accordion = find.byType(ComposerOptionsAccordion);
      expect(tester.getSize(accordion), const Size(44, 44));
      expect(_tooltip("Attach image"), findsNothing);
      expect(find.byIcon(TablerRegular.slash), findsNothing);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(of: accordion, matching: find.byType(DecoratedBox)).first,
                  )
                  .decoration
              as BoxDecoration;
      final prego = tester.element(accordion).prego;
      expect(decoration.color, prego.colors.bgSurface4);
      expect(decoration.border, Border.all(color: prego.colors.borderPrimary));
      expect(decoration.boxShadow, isNull);

      await tester.tap(_tooltip("More actions"));
      await tester.pumpAndSettle();
      expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
      expect(_tooltip("More actions"), findsNothing);
      expect(_tooltip("Hide actions"), findsNothing);
      expect(find.byIcon(TablerRegular.plus), findsOneWidget);
      expect(find.byIcon(TablerRegular.slash), findsOneWidget);
      expect(tester.getSize(accordion), const Size(81, 44));
      final plusCenter = tester.getCenter(find.byIcon(TablerRegular.plus));
      final slashCenter = tester.getCenter(find.byIcon(TablerRegular.slash));
      expect(slashCenter - plusCenter, const Offset(40, 0));

      await tester.tap(_tooltip("Attach image"));
      await tester.pumpAndSettle();
      expect(attachmentPicks, 1);
      expect(commandPicks, 0);
      expect(_tooltip("More actions"), findsOneWidget);
      expect(_tooltip("Attach image"), findsNothing);
      expect(tester.getSize(accordion), const Size(44, 44));

      await tester.tap(_tooltip("More actions"));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(TablerRegular.slash));
      await tester.pumpAndSettle();
      expect(attachmentPicks, 1);
      expect(commandPicks, 1);
      expect(_tooltip("More actions"), findsOneWidget);
      expect(find.byIcon(TablerRegular.slash), findsNothing);
    });
  }

  for (final (name, features) in const [
    ("iOS Reduce Motion", FakeAccessibilityFeatures(reduceMotion: true)),
    ("Android Remove animations", FakeAccessibilityFeatures(disableAnimations: true)),
  ]) {
    testWidgets("$name opens and folds the pill at once", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpAccordion(
        tester: tester,
        brightness: Brightness.dark,
        alwaysOpen: false,
        actionsEnabled: true,
        showAttachImage: true,
        onAttachImageTap: () {},
        onSlashCommandsTap: () {},
      );
      final accordion = find.byType(ComposerOptionsAccordion);
      expect(tester.getSize(accordion).width, 44);

      await tester.tap(_tooltip("More actions"));
      await tester.pump();
      expect(
        tester.getSize(accordion).width,
        ComposerOptionsAccordion.openWidth(showAttachImage: true),
        reason: "Nothing eases on.",
      );
      await tester.tap(_tooltip("Attach image"));
      await tester.pump();
      expect(tester.getSize(accordion).width, 44);
    });
  }

  testWidgets("command-only harnesses show one centred action without a collapse arrow", (tester) async {
    var commandPicks = 0;
    await _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      alwaysOpen: false,
      actionsEnabled: true,
      showAttachImage: false,
      onAttachImageTap: () => fail("Unsupported attachment action was invoked"),
      onSlashCommandsTap: () => commandPicks++,
    );
    await tester.tap(_tooltip("More actions"));
    await tester.pumpAndSettle();
    expect(_tooltip("Attach image"), findsNothing);
    expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
    final accordion = find.byType(ComposerOptionsAccordion);
    expect(tester.getSize(accordion), const Size(44, 44));
    expect(tester.getCenter(find.byIcon(TablerRegular.slash)), tester.getCenter(accordion));
    await tester.tap(find.byIcon(TablerRegular.slash));
    await tester.pumpAndSettle();
    expect(commandPicks, 1);
    expect(_tooltip("More actions"), findsOneWidget);
  });

  testWidgets("an always-open pill shows its actions without an opener and keeps them after a pick", (tester) async {
    var attachmentPicks = 0;
    var commandPicks = 0;
    await _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      alwaysOpen: true,
      actionsEnabled: true,
      showAttachImage: true,
      onAttachImageTap: () => attachmentPicks++,
      onSlashCommandsTap: () => commandPicks++,
    );
    expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
    expect(_tooltip("Attach image"), findsOneWidget);
    expect(find.byIcon(TablerRegular.slash), findsOneWidget);

    await tester.tap(_tooltip("Attach image"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.slash));
    await tester.pumpAndSettle();

    expect(attachmentPicks, 1);
    expect(commandPicks, 1);
    expect(_tooltip("Attach image"), findsOneWidget);
    expect(find.byIcon(TablerRegular.slash), findsOneWidget);
    expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
  });

  testWidgets("typing folds the actions away and the chevron still reopens them", (tester) async {
    Future<void> pump({required bool alwaysOpen, required bool isTyping}) => _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      alwaysOpen: alwaysOpen,
      isTyping: isTyping,
      actionsEnabled: true,
      showAttachImage: true,
      onAttachImageTap: () {},
      onSlashCommandsTap: () {},
    );

    await pump(alwaysOpen: true, isTyping: false);
    expect(_tooltip("Attach image"), findsOneWidget);
    await pump(alwaysOpen: true, isTyping: true);
    expect(_tooltip("Attach image"), findsNothing);
    expect(_tooltip("More actions"), findsOneWidget);

    await tester.tap(_tooltip("More actions"));
    await tester.pumpAndSettle();
    expect(_tooltip("Attach image"), findsOneWidget);

    // A pill opened by hand, here while typing, folds when typing starts again.
    await pump(alwaysOpen: false, isTyping: false);
    expect(_tooltip("Attach image"), findsOneWidget);
    await pump(alwaysOpen: false, isTyping: true);
    expect(_tooltip("Attach image"), findsNothing);
    expect(_tooltip("More actions"), findsOneWidget);
  });

  testWidgets("disabled actions remain inert while the opener still works", (tester) async {
    await _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      alwaysOpen: false,
      actionsEnabled: false,
      showAttachImage: true,
      onAttachImageTap: () => fail("Disabled attachment action was invoked"),
      onSlashCommandsTap: () => fail("Disabled command action was invoked"),
    );
    await tester.tap(_tooltip("More actions"));
    await tester.pumpAndSettle();
    await tester.tap(_tooltip("Attach image"));
    await tester.tap(find.byIcon(TablerRegular.slash));
    await tester.pumpAndSettle();
    expect(_tooltip("Attach image"), findsOneWidget);
    expect(find.byIcon(TablerRegular.slash), findsOneWidget);
    expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
  });

  group("a screen reader", () {
    SemanticsNode nodeNamed(String label) => find.semantics.byLabel(label).evaluate().single;
    const platforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS});

    testWidgets("hears the opener and its actions as named buttons that can be activated", (tester) async {
      final semantics = tester.ensureSemantics();
      var attachmentPicks = 0;
      var commandPicks = 0;
      await _pumpAccordion(
        tester: tester,
        brightness: Brightness.light,
        alwaysOpen: false,
        actionsEnabled: true,
        showAttachImage: true,
        onAttachImageTap: () => attachmentPicks++,
        onSlashCommandsTap: () => commandPicks++,
      );

      expect(
        nodeNamed("More actions"),
        isSemantics(label: "More actions", tooltip: "", isButton: true, isEnabled: true, hasTapAction: true),
      );
      tester.semantics.tap(find.semantics.byLabel("More actions"));
      await tester.pumpAndSettle();

      expect(nodeNamed("Attach image"), isSemantics(label: "Attach image", isButton: true, hasTapAction: true));
      expect(nodeNamed("Slash commands"), isSemantics(label: "Slash commands", isButton: true, hasTapAction: true));
      tester.semantics.tap(find.semantics.byLabel("Slash commands"));
      await tester.pumpAndSettle();
      expect(commandPicks, 1);
      expect(attachmentPicks, 0);
      semantics.dispose();
    }, variant: platforms);

    testWidgets("hears unavailable actions as disabled, with no tap", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpAccordion(
        tester: tester,
        brightness: Brightness.light,
        alwaysOpen: true,
        actionsEnabled: false,
        showAttachImage: true,
        onAttachImageTap: () => fail("Disabled attachment action was invoked"),
        onSlashCommandsTap: () => fail("Disabled command action was invoked"),
      );

      for (final label in ["Attach image", "Slash commands"]) {
        expect(
          nodeNamed(label),
          isSemantics(label: label, isButton: true, hasEnabledState: true, isEnabled: false, hasTapAction: false),
        );
      }
      semantics.dispose();
    }, variant: platforms);
  });

  testWidgets("an attach action whose support is unknown holds its place inert", (tester) async {
    var commandPicks = 0;
    await _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      alwaysOpen: true,
      actionsEnabled: true,
      showAttachImage: true,
      onAttachImageTap: null,
      onSlashCommandsTap: () => commandPicks++,
    );
    expect(_tooltip("Attach image"), findsOneWidget);

    await tester.tap(_tooltip("Attach image"));
    await tester.tap(find.byIcon(TablerRegular.slash));
    await tester.pumpAndSettle();
    expect(commandPicks, 1);
  });
}

Future<void> _pumpAccordion({
  required WidgetTester tester,
  required Brightness brightness,
  required bool alwaysOpen,
  bool isTyping = false,
  required bool actionsEnabled,
  required bool showAttachImage,
  required VoidCallback? onAttachImageTap,
  required VoidCallback onSlashCommandsTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        extensions: [brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: ComposerOptionsAccordion(
            actionsEnabled: actionsEnabled,
            showAttachImage: showAttachImage,
            alwaysOpen: alwaysOpen,
            isTyping: isTyping,
            onAttachImageTap: onAttachImageTap,
            onSlashCommandsTap: onSlashCommandsTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
