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
/// session in the list's default project (D15).
///
/// The project holds once the default settles, so a session elsewhere turning
/// newest never moves a draft; choosing another filter, or another project in
/// the header, moves it.
class const HomeComposerPane({super.key}) extends StatefulWidget {
  @override
  State<HomeComposerPane> createState() => _HomeComposerPaneState();
}

class _HomeComposerPaneState() extends State<HomeComposerPane> {
  String? _filterProjectId;
  String? _heldProjectId;

  /// Counts the sessions this pane started. The page stays under the session
  /// it opens, so each start leaves a fresh composer to come back to.
  int _launches = 0;

  @override
  Widget build(BuildContext context) {
    final (filterProjectId, defaultProjectId) = context.select(
      (AllSessionsCubit cubit) => (cubit.state.projectId, cubit.state.defaultProjectId),
    );
    if (filterProjectId != _filterProjectId) {
      _filterProjectId = filterProjectId;
      _heldProjectId = null;
    }
    final Widget pane = switch (context.watch<ProjectListCubit>().state) {
      ProjectListLoaded(:final projects) when projects.isNotEmpty => _composer(
        projects: projects,
        defaultProjectId: defaultProjectId,
      ),
      // The sidebar shows why there is nothing to start.
      ProjectListLoading() ||
      ProjectListLoaded() ||
      ProjectListFailed() ||
      ProjectListBridgeDisconnected() => PregoGlassScaffold(
        key: const Key("home-composer-pane-empty"),
        title: context.loc.sessionListNewSession,
        titleMode: PregoTopNavigationTitleMode.backLeading,
        banner: ConnectionBanner.maybeFor(context),
        slivers: const [],
      ),
    };
    return AnimatedSwitcher(
      duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
      child: pane,
    );
  }

  Widget _composer({required List<ProjectSummary> projects, required String? defaultProjectId}) {
    ProjectSummary? byId(String? id) => projects.where((project) => project.id == id).firstOrNull;
    final project = byId(_heldProjectId) ?? byId(defaultProjectId) ?? projects.first;
    // Before any session names a default, the first listed project stands in
    // without holding.
    if (_heldProjectId == null && defaultProjectId != null) _heldProjectId = project.id;
    final projectId = project.id;
    final projectName = projectDisplayName(loc: context.loc, project: project);
    return BlocProvider(
      // A different project, or a session started, is a fresh draft.
      key: ValueKey(("home-composer-pane", projectId, _launches)),
      create: (_) => createNewSessionCubit(locator: getIt, projectId: projectId, projectName: projectName),
      child: BlocListener<NewSessionCubit, NewSessionState>(
        listenWhen: (_, current) => current is NewSessionCreated,
        listener: (_, _) => setState(() => _launches++),
        child: NewSessionView(
          projectId: projectId,
          projectName: projectName,
          onProjectSelected: ({required projectId, required projectName}) => setState(() => _heldProjectId = projectId),
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
