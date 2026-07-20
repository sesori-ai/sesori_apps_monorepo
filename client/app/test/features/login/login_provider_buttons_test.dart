import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/login/login_provider_buttons.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

Widget _buildApp({
  required bool isLoading,
  required LoginOption? loadingOption,
  VoidCallback? onGithubSelected,
  VoidCallback? onAppleSelected,
  VoidCallback? onGoogleSelected,
  VoidCallback? onShowEmailForm,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: LoginProviderButtons(
        isLoading: isLoading,
        loadingOption: loadingOption,
        showEmailForm: false,
        showApple: true,
        onGithubSelected: onGithubSelected ?? () {},
        onAppleSelected: onAppleSelected ?? () {},
        onGoogleSelected: onGoogleSelected ?? () {},
        onShowEmailForm: onShowEmailForm ?? () {},
      ),
    ),
  );
}

void main() {
  group("LoginProviderButtons", () {
    testWidgets("spinner replaces only the tapped provider's logo", (tester) async {
      await tester.pumpWidget(
        _buildApp(isLoading: true, loadingOption: LoginOption.google),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(VESPRSolid.google), findsNothing);
      expect(find.byIcon(VESPRSolid.github), findsOneWidget);
      expect(find.byIcon(VESPRSolid.apple), findsOneWidget);
    });

    testWidgets(
      "spinner is the adaptive Cupertino variant on iOS",
      (tester) async {
        await tester.pumpWidget(
          _buildApp(isLoading: true, loadingOption: LoginOption.github),
        );

        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        expect(find.byIcon(VESPRSolid.github), findsNothing);

        // The indicator must carry the button's foreground colour — the
        // default gray ticks are invisible on the dark provider buttons.
        final indicator = tester.widget<CupertinoActivityIndicator>(
          find.byType(CupertinoActivityIndicator),
        );
        expect(indicator.color, isNotNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets("options are untappable but keep enabled styling while one is loading", (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _buildApp(
          isLoading: true,
          loadingOption: LoginOption.github,
          onGithubSelected: () => calls.add("github"),
          onAppleSelected: () => calls.add("apple"),
          onGoogleSelected: () => calls.add("google"),
          onShowEmailForm: () => calls.add("email"),
        ),
      );

      await tester.tap(find.text("Sign in with GitHub"), warnIfMissed: false);
      await tester.tap(find.text("Sign in with Apple"), warnIfMissed: false);
      await tester.tap(find.text("Sign in with Google"), warnIfMissed: false);
      await tester.tap(find.text("Sign in with Email"), warnIfMissed: false);
      await tester.pump();

      expect(calls, isEmpty);

      // A null onPressed is what switches PregoButtonsSolid to its grayed
      // disabled visuals; the design keeps idle options looking normal.
      final buttons = tester.widgetList<PregoButtonsSolid>(find.byType(PregoButtonsSolid));
      expect(buttons.length, equals(4));
      for (final button in buttons) {
        expect(button.onPressed, isNotNull);
      }
    });

    testWidgets("buttons cannot take keyboard focus while one is loading", (tester) async {
      await tester.pumpWidget(
        _buildApp(isLoading: true, loadingOption: LoginOption.github),
      );

      // Keyboard activation (e.g. Enter on a focused button) bypasses the
      // pointer-level AbsorbPointer block, so the buttons must also be
      // unfocusable while a flow is in flight.
      final googleFocus = Focus.of(tester.element(find.text("Sign in with Google")));
      googleFocus.requestFocus();
      await tester.pump();

      expect(googleFocus.hasFocus, isFalse);
    });

    testWidgets("buttons are focusable when idle", (tester) async {
      await tester.pumpWidget(
        _buildApp(isLoading: false, loadingOption: null),
      );

      final googleFocus = Focus.of(tester.element(find.text("Sign in with Google")));
      googleFocus.requestFocus();
      await tester.pump();

      expect(googleFocus.hasFocus, isTrue);
    });

    testWidgets("no provider spinner during an email-form login", (tester) async {
      await tester.pumpWidget(
        _buildApp(isLoading: true, loadingOption: null),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(VESPRSolid.github), findsOneWidget);
      expect(find.byIcon(VESPRSolid.apple), findsOneWidget);
      expect(find.byIcon(VESPRSolid.google), findsOneWidget);
    });

    testWidgets("taps reach their callbacks when idle", (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _buildApp(
          isLoading: false,
          loadingOption: null,
          onGithubSelected: () => calls.add("github"),
          onGoogleSelected: () => calls.add("google"),
        ),
      );

      await tester.tap(find.text("Sign in with GitHub"));
      await tester.tap(find.text("Sign in with Google"));
      await tester.pump();

      expect(calls, equals(["github", "google"]));
    });
  });
}
