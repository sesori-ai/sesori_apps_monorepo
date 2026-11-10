import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_mobile/core/sesori_test_mode.dart";
import "package:sesori_mobile/main.dart" as app;
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";

/// Simulator smoke check: launch, sign in if needed, open the newest session
/// and type into its composer. Needs a running bridge signed in to the same
/// account. See the "Driving the app" section of `client/app/README.md`.
const _email = String.fromEnvironment("SESORI_TEST_EMAIL");
const _password = String.fromEnvironment("SESORI_TEST_PASSWORD");

void main() {
  // Render every frame the app schedules, so animations finish and screenshots
  // show what a user would see, not only the frames the test pumps.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    "signs in once, opens a session and reaches Send by key",
    (tester) async {
      // The app installs its own crash reporter; hand failures back to the
      // test framework so they report instead of tripping its assertion.
      final testErrorHandler = FlutterError.onError;
      _restoreTestErrorHandler = () => FlutterError.onError = testErrorHandler;
      app.main();

      final loc = AppLocalizationsEn();
      final signIn = find.text(loc.signInWithEmail);
      final sessionTile = find.byType(SessionTile);
      await _pumpUntil(tester, () => _shows(signIn) || _shows(sessionTile), "the login or home screen");
      _restoreTestErrorHandler();

      if (_shows(signIn)) {
        await _step("signed out, signing in");
        await tester.tap(signIn);
        await _pumpUntil(tester, () => _shows(find.byType(EditableText)), "the email form");
        await tester.enterText(find.byType(EditableText).at(0), _email);
        await tester.enterText(find.byType(EditableText).at(1), _password);
        await tester.tap(find.text(loc.signIn));
      } else {
        await _step("already signed in");
      }

      await _pumpUntil(tester, () => _shows(sessionTile), "a session on the home screen");
      await _step("home");
      await tester.tap(sessionTile.first);

      // Typing mode rests as a compact pill until tapped.
      final startTyping = find.byKey(PromptInput.startTypingKey);
      await _pumpUntil(tester, () => _shows(startTyping), "the session composer");
      await tester.tap(startTyping);
      final field = find.byKey(PromptInput.textFieldKey);
      await _pumpUntil(tester, () => _shows(field), "the composer text field");
      await tester.enterText(field, "smoke test draft");
      final send = find.descendant(
        of: find.byKey(PromptInput.sendButtonKey),
        matching: find.byType(PregoButtonsSolid),
      );
      await _pumpUntil(tester, () => _shows(send) && tester.widget<PregoButtonsSolid>(send).onPressed != null, "Send");
      await _step("composer typed, send found");
    },
    skip: !sesoriTestMode || _email.isEmpty || _password.isEmpty,
  );
}

/// Prints a line a wrapping script can react to, such as by taking a
/// simulator screenshot, and holds the screen still long enough for it.
Future<void> _step(String name) async {
  // ignore: avoid_print
  print("SMOKE_STEP: $name");
  await Future<void>.delayed(const Duration(seconds: 3));
}

late void Function() _restoreTestErrorHandler;

bool _shows(Finder finder) => finder.evaluate().isNotEmpty;

/// Pumps real frames until [condition] holds.
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      _restoreTestErrorHandler();
      final texts = find
          .byType(Text)
          .evaluate()
          .map((element) => element.widget)
          .whereType<Text>()
          .map((text) => text.data);
      await _step("timed out waiting for $what; on screen: ${texts.nonNulls.join(" | ")}");
      fail("timed out waiting for $what");
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}
