import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/handoff_session_link.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

void main() {
  late _MockSessionDetailCubit cubit;
  late List<({String sessionId, bool readOnly})> returns;

  setUp(() {
    cubit = _MockSessionDetailCubit();
    returns = [];
  });

  Future<void> tapOrigin(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SessionDetailCubit>.value(
          value: cubit,
          child: SessionDetailPresentationScope(
            messageImageRepository: () => throw UnimplementedError(),
            imageSaver: () => throw UnimplementedError(),
            imageClipboard: () => throw UnimplementedError(),
            imageSharer: () => throw UnimplementedError(),
            sessionRepository: () => throw UnimplementedError(),
            createPendingPageCubit: ({required requestId, required sessionId}) =>
                throw StateError("Unused fixture page"),
            createPendingFormCubit: ({required requestId, required sessionId}) => throw UnimplementedError(),
            createFilePreviewCubit: ({required reference}) => throw UnimplementedError(),
            createExternalActionCubit: ({required requestId, required sessionId}) => throw UnimplementedError(),
            canShareImages: false,
            openExternalLink: ({required url, required mode}) async => false,
            openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
            openSideChat: null,
            returnToSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
                returns.add((sessionId: sessionId, readOnly: readOnly)),
            openHarnessSettings: () {},
            openBridgeSettings: () {},
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openForkOrigin(context: context, sessionId: "origin"),
                  child: const Text("origin"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("origin"));
    await tester.pumpAndSettle();
  }

  testWidgets("an archived origin opens read-only from the start", (tester) async {
    when(
      () => cubit.linkedSession(sessionId: "origin"),
    ).thenAnswer((_) async => testSession(id: "origin", archivedAt: DateTime(2026, 11)));

    await tapOrigin(tester);

    expect(returns, [(sessionId: "origin", readOnly: true)]);
  });

  testWidgets("a live origin opens live", (tester) async {
    when(() => cubit.linkedSession(sessionId: "origin")).thenAnswer((_) async => testSession(id: "origin"));

    await tapOrigin(tester);

    expect(returns, [(sessionId: "origin", readOnly: false)]);
  });

  testWidgets("an origin that can't be read answers with an alert", (tester) async {
    when(() => cubit.linkedSession(sessionId: "origin")).thenAnswer((_) async => null);

    await tapOrigin(tester);

    expect(returns, isEmpty);
    expect(find.text("Couldn't open that session"), findsOneWidget);
  });
}
