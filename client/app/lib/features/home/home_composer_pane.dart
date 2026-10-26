import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/mobile_composer_presentation_scope.dart";

/// The content pane beside the sidebar while no session is open: a new
/// session in the list's default project (D15), or, without a default, the
/// project prompt with nothing selected.
///
/// The project holds once a default lands, so a session elsewhere turning
/// newest never moves a draft; choosing another filter, or another project in
/// the header, moves it.
class const HomeComposerPane({super.key}) extends StatefulWidget {
  @override
  State<HomeComposerPane> createState() => _HomeComposerPaneState();
}

class _HomeComposerPaneState() extends State<HomeComposerPane> {
  /// The draft's project, or null until a default lands or one is chosen.
  String? _projectId;

  /// Counts the sessions this pane started. The page stays under the session
  /// it opens, so each start leaves a fresh composer to come back to.
  int _launches = 0;

  @override
  void initState() {
    super.initState();
    _projectId = context.read<AllSessionsCubit>().state.defaultProjectId;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((AllSessionsCubit cubit) => cubit.state.isLoading);
    final Widget pane = switch (context.watch<ProjectListCubit>().state) {
      ProjectListLoaded(:final projects) when projects.isNotEmpty => _composer(
        projects: projects,
        isLoading: isLoading,
      ),
      // The sidebar shows why there is nothing to start.
      ProjectListLoading() || ProjectListLoaded() || ProjectListFailed() || ProjectListBridgeDisconnected() => _empty(),
    };
    return BlocListener<AllSessionsCubit, AllSessionsState>(
      // Another filter moves the draft to its default; until the draft has a
      // project, the first default to land is taken up.
      listenWhen: (previous, current) =>
          previous.projectId != current.projectId ||
          (_projectId == null && previous.defaultProjectId != current.defaultProjectId),
      listener: (_, state) => setState(() => _projectId = state.defaultProjectId),
      child: AnimatedSwitcher(
        duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
        child: pane,
      ),
    );
  }

  Widget _empty() => PregoGlassScaffold(
    key: const Key("home-composer-pane-empty"),
    title: context.loc.sessionListNewSession,
    titleMode: PregoTopNavigationTitleMode.backLeading,
    banner: ConnectionBanner.maybeFor(context),
    slivers: const [],
  );

  /// The draft's composer, or the prompt for its project.
  Widget _composer({required List<ProjectSummary> projects, required bool isLoading}) {
    final project = projects.where((project) => project.id == _projectId).firstOrNull;
    if (project == null) {
      // A list still loading may yet name a default, so the prompt waits.
      if (isLoading) return _empty();
      return NewSessionProjectPrompt(
        key: const Key("home-composer-pane-prompt"),
        onProjectSelected: ({required projectId, required projectName}) => setState(() => _projectId = projectId),
        onBack: null,
        banner: ConnectionBanner.maybeFor(context),
        // Nobody asked for it yet: the pane shows on rotation, a filter
        // change or under an opened session, so the picker waits for a tap.
        opensPicker: false,
        topBar: null,
      );
    }
    final projectId = project.id;
    final projectName = projectDisplayName(loc: context.loc, project: project);
    return BlocProvider(
      // A different project, or a session started, is a fresh draft.
      key: ValueKey(("home-composer-pane", projectId, _launches)),
      create: (_) => createNewSessionCubit(
        locator: getIt,
        projectId: projectId,
        projectName: projectName,
        projectKind: project.kind,
      ),
      child: BlocListener<NewSessionCubit, NewSessionState>(
        listenWhen: (_, current) => current is NewSessionCreated,
        listener: (_, _) => setState(() => _launches++),
        child: NewSessionView(
          projectId: projectId,
          projectName: projectName,
          onProjectSelected: ({required projectId, required projectName}) => setState(() => _projectId = projectId),
          onBack: null,
          onOpenHarnessSettings: () => context.pushRoute(
            const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
          ),
          onSessionCreated: ({required session}) => context.goRoute(
            AppRoute.sessionDetail(
              projectId: projectId,
              projectName: projectName,
              sessionId: session.id,
              sessionTitle: session.title,
              readOnly: false,
              // The session screen takes over the first message in place.
              fromLaunch: true,
            ),
          ),
          composerScopeBuilder: ({required child}) => BlocProvider(
            create: (_) {
              final service = getIt<VoiceTranscriptionService>();
              return VoiceInputCubit(
                service: service,
                session: service.createSession(projectId: projectId),
              );
            },
            child: MobileComposerPresentationScope(child: child),
          ),
          banner: ConnectionBanner.maybeFor(context),
          pageChrome: null,
        ),
      ),
    );
  }
}
