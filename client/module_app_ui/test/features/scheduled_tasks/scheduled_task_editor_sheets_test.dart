import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/scheduled_tasks/scheduled_task_editor_sheets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;

class _FixedTimeZoneSource() implements DeviceTimeZoneSource {
  @override
  Future<String> currentZoneName() async => "UTC";
}

PluginMetadata _harness({required String displayName, required bool compacts}) => PluginMetadata(
  id: displayName.toLowerCase(),
  displayName: displayName,
  isDefault: true,
  state: PluginLifecycleState.ready,
  actionHint: null,
  failureBlock: null,
  mcpScopes: null,
  failureReason: null,
  supportsCompactionOnRequest: compacts,
);

NewSessionState _composingOn({required PluginMetadata harness}) => NewSessionState.composing(
  project: const NewSessionProject(id: "fixture-project", name: "Fixture", kind: ProjectKind.folder),
  config: NewSessionComposeConfig(
    availablePlugins: [harness],
    selectedPlugin: harness,
    supportsFileUploads: false,
    options: const NewSessionOptionsLoadState.unsupported(),
    backendScope: const NewSessionBackendScope.verified(bridgeId: null),
    isPluginDiscoveryInFlight: false,
    projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
  ),
  phase: const NewSessionPhase.idle(),
);

void main() {
  final autoCompactRow = find.byKey(const Key("scheduled-task-auto-compact"));
  PregoSwitch autoCompactSwitch(WidgetTester tester) =>
      tester.widget<PregoSwitch>(find.descendant(of: autoCompactRow, matching: find.byType(PregoSwitch)));

  Future<ScheduledTaskEditorCubit> openSheet(WidgetTester tester, {required PluginMetadata harness}) async {
    final repository = MockScheduledTaskRepository();
    when(repository.listTasks).thenAnswer((_) async => const ScheduledTaskSuccess(value: []));
    final editor = ScheduledTaskEditorCubit(
      repository: repository,
      timeZoneSource: _FixedTimeZoneSource(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      productAnalyticsService: MockProductAnalyticsService(),
      now: () => DateTime(2026, 11, 16, 10, 30),
      taskId: null,
    );
    addTearDown(editor.close);
    final composer = _MockNewSessionCubit();
    whenListen(composer, const Stream<NewSessionState>.empty(), initialState: _composingOn(harness: harness));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ScheduledTaskEditorCubit>.value(value: editor),
          BlocProvider<NewSessionCubit>.value(value: composer),
        ],
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduledTaskEachRunSheet(context: context),
                child: const Text("Each run"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Each run"));
    await tester.pumpAndSettle();
    return editor;
  }

  testWidgets("the switch opens on under Continue and folds away with New session", (tester) async {
    final editor = await openSheet(tester, harness: _harness(displayName: "Claude Code", compacts: true));
    expect(autoCompactRow, findsNothing);

    await tester.tap(find.byKey(const Key("scheduled-task-same-session")));
    await tester.pumpAndSettle();

    expect(autoCompactSwitch(tester).value, isTrue);
    expect(autoCompactSwitch(tester).onChanged, isNotNull);

    await tester.tap(autoCompactRow);
    await tester.pumpAndSettle();
    expect(autoCompactSwitch(tester).value, isFalse);
    expect(
      editor.state,
      isA<ScheduledTaskEditorReady>().having((ready) => ready.runMode, "runMode", isA<TaskRunModeSameSession>()),
    );

    await tester.tap(find.byKey(const Key("scheduled-task-new-session")));
    await tester.pump(const Duration(milliseconds: 50));
    // Still folding away rather than gone at once.
    expect(autoCompactRow, findsOneWidget);
    await tester.pumpAndSettle();
    expect(autoCompactRow, findsNothing);
  });

  testWidgets("a harness that cannot compact shows the switch off and says why on a tap", (tester) async {
    final editor = await openSheet(tester, harness: _harness(displayName: "Copilot", compacts: false));

    await tester.tap(find.byKey(const Key("scheduled-task-same-session")));
    await tester.pumpAndSettle();

    expect(autoCompactSwitch(tester).value, isFalse);
    expect(autoCompactSwitch(tester).onChanged, isNull);

    await tester.tap(find.byType(PregoSwitch));
    await tester.pump();

    expect(find.text("Copilot can't compact on request"), findsOneWidget);
    // The choice is left as it was; Save holds it to what the harness can do.
    expect(
      editor.state,
      isA<ScheduledTaskEditorReady>().having(
        (ready) => ready.runMode,
        "runMode",
        const TaskRunMode.sameSession(autoCompact: true),
      ),
    );
    await tester.pump(PregoPopupAlertPresenter.defaultDuration);
    await tester.pumpAndSettle();
  });
}
