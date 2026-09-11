import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_abort_scope_dialog.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends Mock implements SessionDetailCubit;

void main() {
  testWidgets("follow-up background refusal explains restart recovery", (tester) async {
    final cubit = _MockSessionDetailCubit();
    when(
      () => cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm),
    ).thenAnswer(
      (_) async => const SessionAbortOutcome.rejected(
        rejection: SessionAbortRejection(
          runningSubAgentCount: 1,
          mainAgentRunning: true,
        ),
      ),
    );
    when(
      () => cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop),
    ).thenAnswer(
      (_) async => const SessionAbortOutcome.notAccepted(
        refusal: SessionAbortRefusal(
          kind: SessionAbortRefusalKind.notPerformed,
          reason: SessionAbortRefusalReason.residentWorkCompletionUnknown,
        ),
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => TextButton(
            onPressed: () => stopSessionWithScope(context: context, cubit: cubit),
            child: const Text("stop"),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text("stop"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Stop main agent and 1 sub-agent"));
    await tester.pumpAndSettle();

    expect(find.text("Session not stopped"), findsOneWidget);
    expect(find.textContaining("Restart the harness, then try again."), findsOneWidget);
    verify(() => cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop)).called(1);
  });

  testWidgets("initial background refusal explains restart recovery", (tester) async {
    final cubit = _MockSessionDetailCubit();
    when(
      () => cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm),
    ).thenAnswer(
      (_) async => const SessionAbortOutcome.notAccepted(
        refusal: SessionAbortRefusal(
          kind: SessionAbortRefusalKind.notPerformed,
          reason: SessionAbortRefusalReason.residentWorkCompletionUnknown,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => stopSessionWithScope(context: context, cubit: cubit),
            child: const Text("stop"),
          ),
        ),
      ),
    );

    await tester.tap(find.text("stop"));
    await tester.pumpAndSettle();

    expect(find.text("Session not stopped"), findsOneWidget);
    expect(
      find.text(
        "Sesori couldn’t verify whether background work finished, so it didn’t stop this session. "
        "Restart the harness, then try again.",
      ),
      findsOneWidget,
    );
  });
}
