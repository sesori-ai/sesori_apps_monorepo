import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

Widget _app({
  required Widget child,
  required Brightness brightness,
  required bool disableAnimations,
  required double width,
  required double textScale,
}) => MaterialApp(
  theme: buildPregoThemeData(brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations, textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  ),
);

const _errorText = "The request could not be completed.\nPlease try again.";
const _terminalError = ErrorMessageCard(
  message: MessageError(
    id: "error",
    sessionID: "session",
    agent: null,
    modelID: null,
    providerID: null,
    errorName: "Request failed",
    errorMessage: _errorText,
    time: null,
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("${brightness.name} terminal failures retain verbatim text and use the transcript gutter", (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: _terminalError, brightness: brightness, disableAnimations: true, width: 320, textScale: 2),
      );
      final text = tester.widget<Text>(find.text(_errorText));
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      expect(text.style!.fontSize, 14);
      expect(text.style!.height, closeTo(20 / 14, 0.001));
      expect(text.style!.color, prego.colors.fgErrorPrimary);
      expect(text.maxLines, isNull);
      expect(tester.getTopLeft(find.text(_errorText)).dx, 16);
      expect(find.byType(PregoAiLoader), findsNothing);
      expect(find.byType(PregoShimmer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("${brightness.name} retry history is neutral, not success-coloured", (tester) async {
      await tester.pumpWidget(
        _app(
          child: const RetryPartWidget(attempt: 2, retryError: "Provider unavailable"),
          brightness: brightness,
          disableAnimations: true,
          width: 240,
          textScale: 2,
        ),
      );
      final text = tester.widget<Text>(find.text("Retry #2: Provider unavailable"));
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      expect(text.style!.fontSize, 14);
      expect(text.style!.color, prego.colors.textSecondary);
      expect(tester.widget<Icon>(find.byIcon(TablerRegular.refresh)).color, prego.colors.textTertiary);
      expect(find.byType(PregoShimmer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("active retry keeps its status and full error readable under reduced motion", (tester) async {
    final semantics = tester.ensureSemantics();
    const message = "Provider temporarily unavailable.\nThe next attempt will run automatically.";
    await tester.pumpWidget(
      _app(
        child: const RetryErrorMessageCard(message: message),
        brightness: Brightness.light,
        disableAnimations: true,
        width: 240,
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel("Retrying"), findsOneWidget);
    expect(find.bySemanticsLabel(message), findsOneWidget);
    expect(tester.widget<Text>(find.text(message)).maxLines, isNull);
    expect(tester.getTopLeft(find.text(message)).dx, 40);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets("retry motion follows reduced-motion changes and disposes when removed", (tester) async {
    for (final reduced in [false, true, false]) {
      await tester.pumpWidget(
        _app(
          child: const RetryErrorMessageCard(message: "Provider unavailable"),
          brightness: Brightness.dark,
          disableAnimations: reduced,
          width: 370,
          textScale: 1,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), reduced ? findsNothing : findsOneWidget);
      expect(tester.binding.hasScheduledFrame, !reduced);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
