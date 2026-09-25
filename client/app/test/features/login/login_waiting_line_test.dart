import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/login/login_waiting_line.dart";
import "package:theme_prego/module_prego.dart";

class MockLoginCubit() extends Mock implements LoginCubit;

void main() {
  late MockLoginCubit cubit;

  setUp(() {
    cubit = MockLoginCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream<LoginState>.empty());
    when(() => cubit.cancel()).thenAnswer((_) async {});
  });

  Future<void> pumpLine(WidgetTester tester, {required LoginBrowserLaunch browser}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<LoginCubit>.value(
            value: cubit,
            child: LoginWaitingLine(browser: browser),
          ),
        ),
      ),
    );
  }

  testWidgets("asks the user to confirm in the browser and offers Cancel", (tester) async {
    await pumpLine(tester, browser: LoginBrowserLaunch.opened);

    expect(find.text("Confirm the sign-in in your browser to continue."), findsOneWidget);
    expect(find.text("Could not open browser"), findsNothing);
    await tester.tap(find.text("Cancel"));

    verify(() => cubit.cancel()).called(1);
  });

  testWidgets("says the browser did not open and still offers Cancel", (tester) async {
    await pumpLine(tester, browser: LoginBrowserLaunch.failed);

    expect(find.text("Could not open browser"), findsOneWidget);
    await tester.tap(find.text("Cancel"));

    verify(() => cubit.cancel()).called(1);
  });
}
