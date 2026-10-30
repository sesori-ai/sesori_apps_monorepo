import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Future<void> pumpAppInfo({required WidgetTester tester, required VoidCallback? onBookCall}) => tester.pumpWidget(
    MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettingsAppInfo(
            onBookCall: onBookCall,
            openSupportLink: ({required url}) async {},
            openLegalDocument: ({required document}) async {},
            loadAppVersionInfo: () async => null,
            logo: null,
          ),
        ),
      ),
    ),
  );

  testWidgets("leads the Support section with the CEO call when it is offered", (tester) async {
    var taps = 0;
    await pumpAppInfo(tester: tester, onBookCall: () => taps++);

    final bookCall = find.text("Book a call with the CEO");
    expect(tester.getTopLeft(bookCall).dy, lessThan(tester.getTopLeft(find.text("Email")).dy));

    await tester.tap(bookCall);
    expect(taps, 1);
  });

  testWidgets("hides the CEO call when it is not offered", (tester) async {
    await pumpAppInfo(tester: tester, onBookCall: null);

    expect(find.text("Book a call with the CEO"), findsNothing);
    expect(find.text("Email"), findsOneWidget);
  });
}
