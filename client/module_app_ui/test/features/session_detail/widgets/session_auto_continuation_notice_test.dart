import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_auto_continuation_notice.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _Cubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

void main() {
  final resetAt = DateTime(2030, 9, 25, 10).millisecondsSinceEpoch;
  final continueAt = DateTime(2030, 9, 25, 10, 2).millisecondsSinceEpoch;
  final known = SessionAutoContinuationStatus.resetKnown(resetAt: resetAt, continueAt: continueAt);

  SessionAutoContinuationView view({
    required bool enabled,
    required SessionAutoContinuationStatus status,
    AutoContinuationAvailability availability = AutoContinuationAvailability.conditional,
  }) => SessionAutoContinuationView(enabled: enabled, availability: availability, status: status);

  Future<void> pumpNotice(
    WidgetTester tester, {
    required SessionAutoContinuationView? view,
    required ValueChanged<bool> onChanged,
    bool updating = false,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SessionAutoContinuationNotice(
              view: view,
              updating: updating,
              canInteract: true,
              onEnabledChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets("known reset offers opt-in and shows the bridge's buffered local time", (tester) async {
    bool? changed;
    await pumpNotice(
      tester,
      view: view(enabled: false, status: known),
      onChanged: (value) => changed = value,
    );
    expect(find.textContaining("Sep 25, 2030"), findsOneWidget);
    expect(find.textContaining("10:02"), findsOneWidget);
    expect(find.text("Auto continuation on"), findsNothing);
    await tester.tap(find.byKey(const Key("session-auto-continuation-enable")));
    expect(changed, isTrue);
  });

  testWidgets("unknown reset explains the limit without offering to schedule", (tester) async {
    await pumpNotice(
      tester,
      view: view(enabled: false, status: const SessionAutoContinuationStatus.resetUnknown()),
      onChanged: (_) {},
    );
    expect(find.textContaining("cannot be scheduled"), findsOneWidget);
    expect(find.byKey(const Key("session-auto-continuation-enable")), findsNothing);
  });

  testWidgets("an enabled continuation with nothing due leaves the card to the model-row chip", (tester) async {
    for (final status in [
      const SessionAutoContinuationStatus.idle(),
      SessionAutoContinuationStatus.submitted(acceptedAt: continueAt),
    ]) {
      await pumpNotice(
        tester,
        view: view(enabled: true, status: status),
        onChanged: (_) {},
      );
      expect(find.text("Auto continuation on"), findsNothing, reason: "$status");
      expect(find.byKey(const Key("session-auto-continuation-disable")), findsNothing, reason: "$status");
    }
  });

  test("the card shows only while a continuation is offered, due or needs explaining", () {
    final paused = SessionAutoContinuationStatus.paused(
      resetAt: resetAt,
      continueAt: continueAt,
      reason: AutoContinuationPauseReason.busy,
    );
    const failed = SessionAutoContinuationStatus.submissionFailed(reason: AutoContinuationFailureReason.unknown);
    final cases = <(SessionAutoContinuationStatus, bool, bool)>[
      // (status, visible while enabled, visible while disabled)
      (const SessionAutoContinuationStatus.idle(), false, false),
      (known, true, true),
      (const SessionAutoContinuationStatus.resetUnknown(), true, true),
      (paused, true, false),
      (const SessionAutoContinuationStatus.attemptUnconfirmed(), true, false),
      (SessionAutoContinuationStatus.submitted(acceptedAt: continueAt), false, false),
      (failed, true, false),
      (const SessionAutoContinuationStatus.unknown(), true, false),
    ];
    for (final (status, whenEnabled, whenDisabled) in cases) {
      expect(sessionAutoContinuationNoticeVisible(view: view(enabled: true, status: status)), whenEnabled);
      expect(sessionAutoContinuationNoticeVisible(view: view(enabled: false, status: status)), whenDisabled);
    }
    expect(sessionAutoContinuationNoticeVisible(view: null), isFalse);
  });

  testWidgets("a due continuation can be disabled from the card", (tester) async {
    bool? changed;
    await pumpNotice(
      tester,
      view: view(enabled: true, status: known),
      onChanged: (value) => changed = value,
    );
    expect(find.text("Auto continuation on"), findsOneWidget);
    await tester.tap(find.byKey(const Key("session-auto-continuation-disable")));
    expect(changed, isFalse);
  });

  testWidgets("saving disables the action without displaying an unacknowledged preference", (tester) async {
    var calls = 0;
    await pumpNotice(
      tester,
      view: view(enabled: false, status: known),
      updating: true,
      onChanged: (_) => calls++,
    );
    await tester.tap(find.byKey(const Key("session-auto-continuation-enable")));
    expect(calls, 0);
    expect(find.text("Auto continuation on"), findsNothing);
  });

  testWidgets("unavailable enabled session remains disableable without promising a schedule", (tester) async {
    bool? changed;
    await pumpNotice(
      tester,
      view: view(enabled: true, status: known, availability: AutoContinuationAvailability.unavailable),
      onChanged: (value) => changed = value,
    );
    expect(find.textContaining("unavailable for this harness"), findsOneWidget);
    expect(find.textContaining("Continues at"), findsNothing);
    await tester.tap(find.byKey(const Key("session-auto-continuation-disable")));
    expect(changed, isFalse);
  });

  for (final (status, text) in <(SessionAutoContinuationStatus, String)>[
    (known, "Continues at"),
    (const SessionAutoContinuationStatus.resetUnknown(), "cannot be scheduled"),
    (
      SessionAutoContinuationStatus.paused(
        resetAt: resetAt,
        continueAt: continueAt,
        reason: AutoContinuationPauseReason.awaitingInput,
      ),
      "Paused until you answer",
    ),
    (const SessionAutoContinuationStatus.attemptUnconfirmed(), "could not be confirmed"),
    (
      const SessionAutoContinuationStatus.submissionFailed(reason: AutoContinuationFailureReason.submissionRejected),
      "will not be retried automatically",
    ),
    (const SessionAutoContinuationStatus.unknown(), "cannot be confirmed"),
  ]) {
    testWidgets("renders ${status.runtimeType} at narrow width with enlarged text", (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpNotice(
        tester,
        view: view(enabled: true, status: status),
        onChanged: (_) {},
        textScale: 2,
      );
      expect(find.textContaining(text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("menu waits for a loaded session and can disable after support becomes unavailable", (tester) async {
    final cubit = _Cubit();
    when(() => cubit.state).thenReturn(const SessionDetailState.loading());
    when(() => cubit.setAutoContinuation(enabled: any(named: "enabled"))).thenAnswer((_) async {});
    late PregoMenuItem entry;
    Future<void> pumpMenu(SessionAutoContinuationView? continuation) => tester.pumpWidget(
      BlocProvider<SessionDetailCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              entry = sessionAutoContinuationMenuEntry(
                context: context,
                session: testSession(id: "fixture-session").copyWith(autoContinuation: continuation),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await pumpMenu(view(enabled: false, status: const SessionAutoContinuationStatus.idle()));
    expect(entry.isEnabled, isFalse);
    expect(entry.isSelected, isFalse);

    await pumpMenu(view(enabled: true, status: known, availability: AutoContinuationAvailability.unavailable));
    expect(entry.isEnabled, isTrue);
    expect(entry.isSelected, isTrue);
    expect(entry.subtitle, contains("unavailable for this harness"));
    entry.onTap();
    verify(() => cubit.setAutoContinuation(enabled: false)).called(1);

    await pumpMenu(null);
    expect(entry.isEnabled, isFalse);
    expect(entry.subtitle, contains("Update your bridge"));
    await pumpMenu(view(enabled: false, status: known, availability: AutoContinuationAvailability.unknown));
    expect(entry.isEnabled, isFalse);
    expect(entry.isSelected, isFalse);
  });
}
