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
/// the header, moves the composer there with what it holds.
class const HomeComposerPane({super.key}) extends StatefulWidget {
  @override
  State<HomeComposerPane> createState() => _HomeComposerPaneState();
}

class _HomeComposerPaneState() extends State<HomeComposerPane> {
  /// The project the next composer starts in, or null until a default lands
  /// or one is chosen. Once a composer is up, it owns its project.
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
      // Until a composer is up, the first default to land, or another
      // filter's, is where it starts.
      listenWhen: (previous, current) =>
          _projectId == null &&
          (previous.projectId != current.projectId || previous.defaultProjectId != current.defaultProjectId),
      listener: (_, state) => setState(() => _projectId = state.defaultProjectId),
      child: AnimatedSwitcher(
        duration: _motionDuration,
        child: pane,
      ),
    );
  }

  Duration get _motionDuration => context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220);

  Widget _empty() => PregoGlassScaffold(
    key: const Key("home-composer-pane-empty"),
    title: context.loc.sessionListNewSession,
    titleMode: PregoTopNavigationTitleMode.backLeading,
    banner: ConnectionBanner.maybeFor(context),
    slivers: const [],
  );

  Widget _prompt({required NewSessionProjectSelected onProjectSelected}) => NewSessionProjectPrompt(
    key: const Key("home-composer-pane-prompt"),
    onProjectSelected: onProjectSelected,
    onBack: null,
    banner: ConnectionBanner.maybeFor(context),
    // Nobody asked for it yet: the pane shows on rotation, a filter
    // change or under an opened session, so the picker waits for a tap.
    opensPicker: false,
    topBar: null,
  );

  /// [projectId] as the composer names it.
  NewSessionProject _project({required List<ProjectSummary> projects, required String projectId}) {
    final project = projects.where((project) => project.id == projectId).firstOrNull;
    return NewSessionProject(
      id: projectId,
      name: project == null ? null : projectDisplayName(loc: context.loc, project: project),
      kind: project?.kind ?? ProjectKind.folder,
    );
  }

  /// The draft's composer, or the prompt for its project.
  Widget _composer({required List<ProjectSummary> projects, required bool isLoading}) {
    final projectId = _projectId;
    if (projectId == null) {
      // A list still loading may yet name a default, so the prompt waits.
      if (isLoading) return _empty();
      return _prompt(
        onProjectSelected: ({required projectId, required projectName}) => setState(() => _projectId = projectId),
      );
    }
    return BlocProvider(
      // A session started is a fresh draft; another project moves this one.
      key: ValueKey(("home-composer-pane", _launches)),
      create: (_) => createNewSessionCubit(
        locator: getIt,
        project: _project(projects: projects, projectId: projectId),
      ),
      child: MultiBlocListener(
        listeners: [
          BlocListener<NewSessionCubit, NewSessionState>(
            listenWhen: (_, current) => current is NewSessionCreated,
            // The next composer starts where this one's session did.
            listener: (_, state) => setState(() {
              _launches++;
              _projectId = state.project.id;
            }),
          ),
          BlocListener<AllSessionsCubit, AllSessionsState>(
            // Another filter moves the composer to its default.
            listenWhen: (previous, current) => previous.projectId != current.projectId,
            listener: (context, state) {
              final projectId = state.defaultProjectId;
              if (projectId == null) return;
              context.read<NewSessionCubit>().selectProject(
                project: _project(projects: projects, projectId: projectId),
              );
            },
          ),
        ],
        child: Builder(
          builder: (context) => _listedComposer(context: context, projects: projects, isLoading: isLoading),
        ),
      ),
    );
  }

  /// The composer while its project is listed, and otherwise the prompt,
  /// which moves the same composer to the project chosen.
  Widget _listedComposer({
    required BuildContext context,
    required List<ProjectSummary> projects,
    required bool isLoading,
  }) {
    final projectId = context.select((NewSessionCubit cubit) => cubit.state.project.id);
    final listed = projects.any((project) => project.id == projectId);
    void select({required String projectId, required String projectName}) =>
        context.read<NewSessionCubit>().selectProject(
          project: _project(projects: projects, projectId: projectId),
        );
    return AnimatedSwitcher(
      duration: _motionDuration,
      child: switch (listed) {
        true => NewSessionView(
          key: const Key("home-composer-pane-composer"),
          onProjectSelected: select,
          onBack: null,
          onOpenHarnessSettings: () => context.pushRoute(
            const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
          ),
          onSessionCreated: ({required session, required project}) => context.goRoute(
            AppRoute.sessionDetail(
              projectId: project.id,
              projectName: project.name,
              sessionId: session.id,
              sessionTitle: session.title,
              readOnly: false,
              // The session screen takes over the first message in place.
              fromLaunch: true,
            ),
          ),
          composerScopeBuilder: ({required projectId, required child}) => BlocProvider(
            create: (_) {
              final service = getIt<VoiceTranscriptionService>();
              return VoiceInputCubit(
                service: service,
                session: service.createSession(projectId: projectId, allowLive: true),
              );
            },
            child: MobileComposerPresentationScope(child: child),
          ),
          banner: ConnectionBanner.maybeFor(context),
          pageChrome: null,
        ),
        // A list still loading may yet name it.
        false when isLoading => _empty(),
        false => _prompt(onProjectSelected: select),
      },
    );
  }
}
