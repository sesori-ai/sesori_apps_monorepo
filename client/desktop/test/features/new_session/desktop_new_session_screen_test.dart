import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:theme_prego/module_prego.dart";

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;

class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

const _state = NewSessionState.composing(
  config: NewSessionComposeConfig(
    availablePlugins: [],
    selectedPlugin: null,
    options: NewSessionOptionsLoadState.unsupported(),
    backendScope: NewSessionBackendScope.verified(bridgeId: null),
    isPluginDiscoveryInFlight: false,
    projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
  ),
  phase: NewSessionPhase.idle(),
);

void main() {
  testWidgets("desktop new session is text-first and exposes worktree options without voice", (tester) async {
    final newSessionCubit = _MockNewSessionCubit();
    final inputModeCubit = _MockChatInputModeCubit();
    when(() => newSessionCubit.state).thenReturn(_state);
    whenListen(newSessionCubit, const Stream<NewSessionState>.empty(), initialState: _state);
    when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
    when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
    when(() => newSessionCubit.canCreateSession).thenReturn(true);
    when(() => newSessionCubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(() => inputModeCubit.state).thenReturn(ChatInputMode.textFirst);
    whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
          BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopNewSessionView(
            projectId: "project-1",
            projectName: "Sesori",
            onBack: () {},
            onOpenHarnessSettings: () {},
            onSessionCreated: ({required session}) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("New session"), findsOneWidget);
    expect(find.text("Dedicated workspace"), findsOneWidget);
    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.bySemanticsLabel("Start recording"), findsNothing);

    await tester.tap(find.text("Ask anything..."));
    await tester.pump();
    expect(find.byType(EditableText), findsOneWidget);
  });
}
