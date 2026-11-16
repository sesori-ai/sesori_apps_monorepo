import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "../new_session/new_session_project_prompt.dart";
import "../new_session/new_session_view.dart";
import "../project_list/project_path_labels.dart";
import "../session_detail/widgets/prompt_input.dart";
import "scheduled_task_editor_sheets.dart";
import "scheduled_task_formatter.dart";
import "scheduled_tasks_view.dart";

/// The New task screen, or the same screen editing a task. The composer holds
/// the prompt and where the task runs. The When and Each run lines above it
/// open their sheets, and Save task sends it all to the computer. The product
/// shell owns the cubits' dependencies and the routes.
class const ScheduledTaskEditorView({
  super.key,
  required final ScheduledTaskEditorCubit Function() createCubit,
  required final NewSessionCubit Function({required NewSessionPurpose purpose}) createComposerCubit,
  required final VoidCallback onBack,

  /// Leaves the screen once the computer saved the task.
  required final VoidCallback onSaved,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionComposerScopeBuilder composerScopeBuilder,
  required final Widget? banner,

  /// A pointer surface's page frame, titled [title]; null keeps the glass bar.
  required final NewSessionPageChrome Function({required String title})? pageChrome,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createCubit(),
    child: BlocBuilder<ScheduledTaskEditorCubit, ScheduledTaskEditorState>(
      // Only a change of page rebuilds here; the lines follow choices below.
      buildWhen: (previous, next) => previous.runtimeType != next.runtimeType,
      builder: (context, state) {
        final title = switch (state) {
          ScheduledTaskEditorReady(editing: _?) => context.loc.scheduledTaskEditTitle,
          _ => context.loc.scheduledTaskNew,
        };
        final chrome = pageChrome?.call(title: title);
        return switch (state) {
          ScheduledTaskEditorLoading() => _StatusFrame(
            title: title,
            topBar: chrome?.topBar,
            onBack: onBack,
            child: const Center(child: PregoActivityIndicator(color: null)),
          ),
          ScheduledTaskEditorUnavailable(:final reason) => _StatusFrame(
            title: title,
            topBar: chrome?.topBar,
            onBack: onBack,
            child: _Unavailable(reason: reason),
          ),
          ScheduledTaskEditorReady(:final editing) => _TaskComposer(
            editing: editing,
            title: title,
            createComposerCubit: createComposerCubit,
            onBack: onBack,
            onSaved: onSaved,
            onOpenHarnessSettings: onOpenHarnessSettings,
            composerScopeBuilder: composerScopeBuilder,
            banner: banner,
            chrome: chrome,
          ),
        };
      },
    ),
  );
}

/// A page with nothing to compose yet: loading, or why the task cannot open.
class const _StatusFrame({
  required final String title,
  required final Widget? topBar,
  required final VoidCallback onBack,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final body = SliverPadding(
      padding: const EdgeInsets.all(PregoSpacing.xl),
      sliver: SliverFillRemaining(hasScrollBody: false, child: child),
    );
    if (topBar case final topBar?) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(slivers: [SliverToBoxAdapter(child: topBar), body]),
      );
    }
    return PregoGlassScaffold(
      title: title,
      onBack: onBack,
      titleMode: PregoTopNavigationTitleMode.backLeading,
      subtitle: null,
      banner: null,
      slivers: [body],
    );
  }
}

class const _Unavailable({required final ScheduledTaskEditorUnavailableReason reason}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Align(
      alignment: Alignment.topCenter,
      child: switch (reason) {
        ScheduledTaskEditorUnavailableReason.loadFailed => ScheduledTaskStatusRow(
          key: const Key("scheduled-task-editor-failed"),
          icon: TablerRegular.alert_circle,
          title: loc.scheduledTasksLoadFailed,
          trailing: PregoButtonsSolid(
            label: loc.scheduledTasksRetry,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: () => unawaited(context.read<ScheduledTaskEditorCubit>().retry()),
          ),
          onTap: null,
        ),
        ScheduledTaskEditorUnavailableReason.bridgeOutdated => const ScheduledTasksBridgeOutdatedRow(),
        ScheduledTaskEditorUnavailableReason.taskGone => _Note(text: loc.scheduledTaskGone),
        ScheduledTaskEditorUnavailableReason.newerApp => _Note(text: loc.scheduledTaskReadOnly),
      },
    );
  }
}

class const _Note({required final String text}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xl),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
  );
}

/// The composer for the task, after a new task has its project.
class const _TaskComposer({
  required final ScheduledTask? editing,
  required final String title,
  required final NewSessionCubit Function({required NewSessionPurpose purpose}) createComposerCubit,
  required final VoidCallback onBack,
  required final VoidCallback onSaved,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionComposerScopeBuilder composerScopeBuilder,
  required final Widget? banner,
  required final NewSessionPageChrome? chrome,
}) extends StatefulWidget {
  @override
  State<_TaskComposer> createState() => _TaskComposerState();
}

class _TaskComposerState() extends State<_TaskComposer> {
  /// What the composer opens with: the edited task's choices, or a new
  /// task's defaults once its project is picked.
  late TaskComposerSelection? _selection = switch (widget.editing) {
    final task? => task.definition.composerSelection(project: _project(projectId: task.definition.projectId)),
    null => null,
  };

  NewSessionProject _project({required String projectId}) {
    final state = context.read<ProjectListCubit>().state;
    return NewSessionProject(
      id: projectId,
      name: switch (state) {
        ProjectListLoaded(:final projects) => [
          for (final project in projects)
            if (project.id == projectId) projectDisplayName(loc: context.loc, project: project),
        ].firstOrNull,
        ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
      },
      kind: state.kindOf(projectId: projectId),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
    child: switch (_selection) {
      null => NewSessionProjectPrompt(
        key: const Key("scheduled-task-editor-project"),
        title: widget.title,
        onProjectSelected: ({required projectId, required projectName}) => setState(() {
          _selection = newTaskComposerSelection(
            project: NewSessionProject(
              id: projectId,
              name: projectName,
              kind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
            ),
          );
        }),
        onBack: widget.onBack,
        banner: widget.banner,
        opensPicker: true,
        offersFirstRunStep: false,
        topBar: widget.chrome?.topBar,
      ),
      final TaskComposerSelection selection => BlocProvider(
        key: const Key("scheduled-task-editor-composer"),
        create: (_) => widget.createComposerCubit(purpose: NewSessionPurpose.editTask(initialSelection: selection)),
        child: MultiBlocListener(
          listeners: [
            BlocListener<NewSessionCubit, NewSessionState>(
              listenWhen: (previous, next) => previous.phase != next.phase,
              listener: (context, state) {
                if (state.phase case NewSessionPhaseTaskSubmitted(:final submission)) {
                  unawaited(context.read<ScheduledTaskEditorCubit>().save(submission: submission));
                }
              },
            ),
            BlocListener<ScheduledTaskEditorCubit, ScheduledTaskEditorState>(
              listenWhen: (previous, next) => !_isSaved(previous) && _isSaved(next),
              listener: (_, _) => widget.onSaved(),
            ),
          ],
          child: Builder(
            builder: (context) => NewSessionView(
              onProjectSelected: ({required projectId, required projectName}) =>
                  context.read<NewSessionCubit>().selectProject(
                    project: NewSessionProject(
                      id: projectId,
                      name: projectName,
                      kind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
                    ),
                  ),
              onBack: widget.onBack,
              onOpenHarnessSettings: widget.onOpenHarnessSettings,
              // A task's composer saves instead; it never starts a session.
              onSessionCreated: ({required session, required project}) {},
              composerScopeBuilder: widget.composerScopeBuilder,
              banner: widget.banner,
              pageChrome: widget.chrome,
              aboveComposer: const _TaskLines(),
              submitAction: PromptSubmitAction(label: context.loc.scheduledTaskSave, icon: TablerRegular.calendar_check),
            ),
          ),
        ),
      ),
    },
  );

  static bool _isSaved(ScheduledTaskEditorState state) =>
      state is ScheduledTaskEditorReady && state.save is ScheduledTaskEditorSaved;
}

/// The When and Each run lines, and how the last Save went.
class const _TaskLines() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ready = context.select(
      (ScheduledTaskEditorCubit cubit) => switch (cubit.state) {
        final ScheduledTaskEditorReady ready => ready,
        ScheduledTaskEditorLoading() || ScheduledTaskEditorUnavailable() => null,
      },
    );
    if (ready == null) return const SizedBox.shrink();
    final loc = context.loc;
    final prego = context.prego;
    final labels = ScheduledTaskFormatter(loc: loc, now: DateTime.now);
    final whenProblem = switch (ready.save) {
      ScheduledTaskEditorRefused(:final code) => _whenProblem(loc: loc, code: code, schedule: ready.schedule),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SaveStatus(save: ready.save),
          PregoGroupedRows(
            children: [
              PregoGroupedRow(
                key: const Key("scheduled-task-editor-when"),
                icon: TablerRegular.calendar_time,
                title: Text(loc.scheduledTaskWhen),
                subtitle: Text(
                  whenProblem ?? labels.draftSchedule(schedule: ready.schedule, editing: ready.editing),
                  style: whenProblem == null ? null : TextStyle(color: prego.colors.textErrorPrimary),
                ),
                trailing: const Icon(TablerRegular.chevron_right),
                onTap: () => unawaited(showScheduledTaskWhenSheet(context: context)),
              ),
              PregoGroupedRow(
                key: const Key("scheduled-task-editor-each-run"),
                icon: TablerRegular.player_play,
                title: Text(loc.scheduledTaskEachRun),
                subtitle: Text(
                  [
                    switch (ready.runMode) {
                      TaskRunModeSameSession() => loc.scheduledTaskContinuesSession,
                      TaskRunModeNewSession() || TaskRunModeUnknown() => loc.scheduledTaskStartsNewSession,
                    },
                    switch (ready.approvalMode) {
                      TaskApprovalMode.approveAll => loc.scheduledTaskApprovalsAll,
                      TaskApprovalMode.ask || TaskApprovalMode.unknown => loc.scheduledTaskApprovalsAsk,
                    },
                  ].join(" · "),
                ),
                trailing: const Icon(TablerRegular.chevron_right),
                onTap: () => unawaited(showScheduledTaskEachRunSheet(context: context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A refusal about the schedule, worded for the When line; null for one
  /// the status above the lines words.
  static String? _whenProblem({
    required AppLocalizations loc,
    required ScheduledTaskErrorCode code,
    required TaskSchedule schedule,
  }) => switch (code) {
    ScheduledTaskErrorCode.onceTimeInPast => loc.scheduledTaskOnceInPast,
    ScheduledTaskErrorCode.invalidSchedule when schedule is TaskScheduleWeekly && schedule.days.isEmpty =>
      loc.scheduledTaskNoDays,
    ScheduledTaskErrorCode.invalidSchedule ||
    ScheduledTaskErrorCode.hoursOutOfRange ||
    ScheduledTaskErrorCode.unknownTimeZone => loc.scheduledTaskInvalidSchedule,
    _ => null,
  };
}

/// Saving, or why the last Save did not land, above the lines. It grows and
/// shrinks in place, so the lines and the composer below never jump.
class const _SaveStatus({required final ScheduledTaskEditorSave save}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    Widget text(String text, {required bool isError}) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md, start: PregoSpacing.xs),
      child: Text(
        text,
        style: prego.textTheme.textSm.regular.copyWith(
          color: isError ? prego.colors.textErrorPrimary : prego.colors.textSecondary,
        ),
      ),
    );
    final Widget? status = switch (save) {
      ScheduledTaskEditorSaving() => text(loc.scheduledTaskSaving, isError: false),
      ScheduledTaskEditorSaveFailed() => text(loc.scheduledTaskSaveFailed, isError: true),
      ScheduledTaskEditorSaveBridgeOutdated() => const Padding(
        padding: EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
        child: ScheduledTasksBridgeOutdatedRow(),
      ),
      ScheduledTaskEditorRefused(:final code) => switch (_problem(loc: loc, code: code)) {
        final problem? => text(problem, isError: true),
        null => null,
      },
      ScheduledTaskEditorSaveIdle() || ScheduledTaskEditorSaved() => null,
    };
    return AnimatedSize(
      duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.bottomStart,
      child: KeyedSubtree(key: const Key("scheduled-task-editor-status"), child: status ?? const SizedBox(width: double.infinity)),
    );
  }

  /// A refusal the When line does not show; null for those it does.
  static String? _problem({required AppLocalizations loc, required ScheduledTaskErrorCode code}) => switch (code) {
    ScheduledTaskErrorCode.onceTimeInPast ||
    ScheduledTaskErrorCode.invalidSchedule ||
    ScheduledTaskErrorCode.hoursOutOfRange ||
    ScheduledTaskErrorCode.unknownTimeZone => null,
    ScheduledTaskErrorCode.emptyPrompt || ScheduledTaskErrorCode.emptyName => loc.scheduledTaskEmptyPrompt,
    ScheduledTaskErrorCode.unknownProject => loc.scheduledTaskUnknownProject,
    ScheduledTaskErrorCode.unknownHarness => loc.scheduledTaskUnknownHarness,
    ScheduledTaskErrorCode.unsupportedByBridge => loc.scheduledTaskRunNowUnsupported,
    ScheduledTaskErrorCode.taskNotFound => loc.scheduledTaskGone,
    ScheduledTaskErrorCode.previousRunActive => loc.scheduledTaskPreviousRunActive,
    ScheduledTaskErrorCode.unknown => loc.scheduledTaskSaveFailed,
  };
}
