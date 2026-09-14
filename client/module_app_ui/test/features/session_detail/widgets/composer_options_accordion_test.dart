import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/composer_options_accordion.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("${brightness.name}: actions replace the opener and collapse after selection", (tester) async {
      var attachmentPicks = 0;
      var commandPicks = 0;
      await _pumpAccordion(
        tester: tester,
        brightness: brightness,
        actionsEnabled: true,
        showAttachImage: true,
        onAttachImageTap: () => attachmentPicks++,
        onSlashCommandsTap: () => commandPicks++,
      );

      final accordion = find.byType(ComposerOptionsAccordion);
      expect(tester.getSize(accordion), const Size(44, 44));
      expect(find.byTooltip("Attach image"), findsNothing);
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

      await tester.tap(find.byTooltip("More actions"));
      await tester.pumpAndSettle();
      expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
      expect(find.byTooltip("More actions"), findsNothing);
      expect(find.byTooltip("Hide actions"), findsNothing);
      expect(find.byIcon(TablerRegular.plus), findsOneWidget);
      expect(find.byIcon(TablerRegular.slash), findsOneWidget);
      expect(tester.getSize(accordion), const Size(81, 44));
      final plusCenter = tester.getCenter(find.byIcon(TablerRegular.plus));
      final slashCenter = tester.getCenter(find.byIcon(TablerRegular.slash));
      expect(slashCenter - plusCenter, const Offset(40, 0));

      await tester.tap(find.byTooltip("Attach image"));
      await tester.pumpAndSettle();
      expect(attachmentPicks, 1);
      expect(commandPicks, 0);
      expect(find.byTooltip("More actions"), findsOneWidget);
      expect(find.byTooltip("Attach image"), findsNothing);
      expect(tester.getSize(accordion), const Size(44, 44));

      await tester.tap(find.byTooltip("More actions"));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(TablerRegular.slash));
      await tester.pumpAndSettle();
      expect(attachmentPicks, 1);
      expect(commandPicks, 1);
      expect(find.byTooltip("More actions"), findsOneWidget);
      expect(find.byIcon(TablerRegular.slash), findsNothing);
    });
  }

  testWidgets("command-only harnesses show one centred action without a collapse arrow", (tester) async {
    var commandPicks = 0;
    await _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      actionsEnabled: true,
      showAttachImage: false,
      onAttachImageTap: () => fail("Unsupported attachment action was invoked"),
      onSlashCommandsTap: () => commandPicks++,
    );
    await tester.tap(find.byTooltip("More actions"));
    await tester.pumpAndSettle();
    expect(find.byTooltip("Attach image"), findsNothing);
    expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
    final accordion = find.byType(ComposerOptionsAccordion);
    expect(tester.getSize(accordion), const Size(44, 44));
    expect(tester.getCenter(find.byIcon(TablerRegular.slash)), tester.getCenter(accordion));
    await tester.tap(find.byIcon(TablerRegular.slash));
    await tester.pumpAndSettle();
    expect(commandPicks, 1);
    expect(find.byTooltip("More actions"), findsOneWidget);
  });

  testWidgets("disabled actions remain inert while the opener still works", (tester) async {
    await _pumpAccordion(
      tester: tester,
      brightness: Brightness.light,
      actionsEnabled: false,
      showAttachImage: true,
      onAttachImageTap: () => fail("Disabled attachment action was invoked"),
      onSlashCommandsTap: () => fail("Disabled command action was invoked"),
    );
    await tester.tap(find.byTooltip("More actions"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Attach image"));
    await tester.tap(find.byIcon(TablerRegular.slash));
    await tester.pumpAndSettle();
    expect(find.byTooltip("Attach image"), findsOneWidget);
    expect(find.byIcon(TablerRegular.slash), findsOneWidget);
    expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
  });
}

Future<void> _pumpAccordion({
  required WidgetTester tester,
  required Brightness brightness,
  required bool actionsEnabled,
  required bool showAttachImage,
  required VoidCallback onAttachImageTap,
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
            onAttachImageTap: onAttachImageTap,
            onSlashCommandsTap: onSlashCommandsTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
