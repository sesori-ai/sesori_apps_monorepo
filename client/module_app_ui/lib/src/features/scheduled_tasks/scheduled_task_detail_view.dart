import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/rename_sheet.dart";
import "../project_list/project_path_labels.dart";
import "../session_list/session_list_headings.dart";
import "scheduled_task_formatter.dart";
import "scheduled_tasks_view.dart";

typedef OpenScheduledTaskRunSession = void Function({
  required String projectId,
  required String? projectName,
  required String sessionId,
});

/// A scheduled task's own page: when it runs, Run now, Pause/Resume, Edit,
/// Rename and Delete, and its run history. A run row opens the run's session,
/// or, for a run that couldn't start, a sheet saying why. A task with parts
/// from a newer app can still be run, paused and deleted, but not edited or
/// renamed. The product shell owns the cubit's dependencies and the routes.
class const ScheduledTaskDetailView({
  super.key,
  required final ScheduledTaskDetailCubit Function() createCubit,
  required final VoidCallback onBack,

  /// Leaves the page after the task was deleted.
  required final VoidCallback onDeleted,

  /// Opens the task in the editor.
  required final VoidCallback onEdit,

  /// Opens a run's session over this page, so Back returns here.
  required final OpenScheduledTaskRunSession onOpenSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createCubit(),
    child: Builder(
      builder: (context) {
        final state = context.watch<ScheduledTaskDetailCubit>().state;
        return PregoGlassScaffold(
          title: switch (state) {
            ScheduledTaskDetailLoaded(:final task) => task.definition.name,
            _ => context.loc.scheduledTasksTitle,
          },
          titleMode: PregoTopNavigationTitleMode.inline,
          onBack: onBack,
          automaticallyImplyLeading: false,
          onRefresh: () => context.read<ScheduledTaskDetailCubit>().refresh(),
          slivers: [
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                PregoSpacing.xl,
                0,
                PregoSpacing.xl,
                PregoSpacing.xl + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: switch (state) {
                ScheduledTaskDetailLoading() => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: PregoActivityIndicator(color: null)),
                ),
                ScheduledTaskDetailFailed() => SliverToBoxAdapter(
                  child: ScheduledTaskStatusRow(
                    icon: TablerRegular.alert_circle,
                    title: context.loc.scheduledTasksLoadFailed,
                    trailing: PregoButtonsSolid(
                      label: context.loc.scheduledTasksRetry,
                      hierarchy: PregoButtonsSolidHierarchy.secondary,
                      size: PregoButtonsSolidSize.sm,
                      onPressed: () => unawaited(context.read<ScheduledTaskDetailCubit>().retry()),
                    ),
                    onTap: null,
                  ),
                ),
                ScheduledTaskDetailBridgeOutdated() => const SliverToBoxAdapter(
                  child: ScheduledTasksBridgeOutdatedRow(),
                ),
                ScheduledTaskDetailGone() => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: _SecondaryText(text: context.loc.scheduledTaskGone)),
                ),
                ScheduledTaskDetailLoaded(
                  :final task,
                  :final runs,
                  :final editable,
                  :final deviceTimeZone,
                ) =>
                  SliverList.list(
                    children: [
                      if (!editable)
                        Padding(
                          key: const Key("scheduled-task-read-only"),
                          padding: const EdgeInsetsDirectional.only(top: PregoSpacing.md),
                          child: _SecondaryText(text: context.loc.scheduledTaskReadOnly),
                        ),
                      _Summary(task: task, deviceTimeZone: deviceTimeZone),
                      _Actions(task: task, editable: editable, onDeleted: onDeleted, onEdit: onEdit),
                      SessionListHeading(heading: context.loc.scheduledTaskRunsHeading, isFirst: false, action: null),
                      _History(
                        task: task,
                        runs: runs,
                        editable: editable,
                        onEdit: onEdit,
                        onOpenSession: onOpenSession,
                      ),
                    ],
                  ),
              },
            ),
          ],
          titleKeptSuffix: null,
        );
      },
    ),
  );
}

class const _Summary({required final ScheduledTask task, required final String? deviceTimeZone})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final labels = ScheduledTaskFormatter(loc: loc, now: DateTime.now);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: PregoSpacing.md),
      child: PregoGroupedRows(
        children: [
          PregoGroupedRow(
            icon: task.definition.schedule is TaskScheduleOnce ? TablerRegular.clock : TablerRegular.repeat,
            title: Text(loc.scheduledTaskWhen),
            subtitle: Text(labels.schedule(task: task, deviceTimeZone: deviceTimeZone)),
          ),
          PregoGroupedRow(
            icon: TablerRegular.calendar_time,
            title: Text(loc.scheduledTaskNextRun),
            subtitle: Text(labels.nextRun(task: task)),
          ),
        ],
      ),
    );
  }
}

class const _Actions({
  required final ScheduledTask task,
  required final bool editable,
  required final VoidCallback onDeleted,
  required final VoidCallback onEdit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xl),
      child: PregoGroupedRows(
        children: [
          PregoGroupedRow(
            key: const Key("scheduled-task-run-now"),
            icon: TablerRegular.player_play,
            title: Text(loc.scheduledTaskRunNow),
            onTap: () => unawaited(_runNow(context: context)),
          ),
          PregoGroupedRow(
            key: const Key("scheduled-task-pause"),
            icon: task.enabled ? TablerRegular.player_pause : TablerRegular.repeat,
            title: Text(task.enabled ? loc.scheduledTaskPause : loc.scheduledTaskResume),
            onTap: () => unawaited(_setEnabled(context: context, enabled: !task.enabled)),
          ),
          if (editable)
            PregoGroupedRow(
              key: const Key("scheduled-task-edit"),
              icon: TablerRegular.adjustments_horizontal,
              title: Text(loc.scheduledTaskEdit),
              trailing: const Icon(TablerRegular.chevron_right),
              onTap: onEdit,
            ),
          if (editable)
            PregoGroupedRow(
              key: const Key("scheduled-task-rename"),
              icon: TablerRegular.pencil,
              title: Text(loc.scheduledTaskRename),
              onTap: () => unawaited(_rename(context: context)),
            ),
          PregoGroupedRow(
            key: const Key("scheduled-task-delete"),
            // The same 24px slot an icon row gets, so the title lines up with the rows above.
            leading: SizedBox(
              width: 24,
              child: Icon(TablerRegular.trash, size: 20, color: context.prego.colors.textErrorPrimary),
            ),
            title: Text(loc.scheduledTaskDelete, style: TextStyle(color: context.prego.colors.textErrorPrimary)),
            onTap: () => unawaited(_delete(context: context)),
          ),
        ],
      ),
    );
  }

  Future<void> _runNow({required BuildContext context}) async {
    final loc = context.loc;
    final presenter = PregoPopupAlertPresenter.of(context);
    final labels = ScheduledTaskFormatter(loc: loc, now: DateTime.now);
    final (message, variant) = switch (await context.read<ScheduledTaskDetailCubit>().runNow()) {
      ScheduledTaskSuccess(value: ScheduledTaskRun(outcome: ScheduledTaskRunFailed(:final reason))) => (
        loc.scheduledTaskRunFailed(labels.failureReason(reason: reason)),
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ScheduledTaskSuccess() => (loc.scheduledTaskRunStarted, PregoPopupAlertsNotificationsVariant.success),
      ScheduledTaskRefused(code: ScheduledTaskErrorCode.previousRunActive) => (
        loc.scheduledTaskPreviousRunActive,
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ScheduledTaskRefused(code: ScheduledTaskErrorCode.taskNotFound) => (
        loc.scheduledTaskGone,
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ScheduledTaskRefused(code: ScheduledTaskErrorCode.unsupportedByBridge) => (
        loc.scheduledTaskRunNowUnsupported,
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ScheduledTaskRefused() || ScheduledTaskBridgeOutdated() || ScheduledTaskFailure() => (
        loc.scheduledTaskRunNowFailed,
        PregoPopupAlertsNotificationsVariant.error,
      ),
    };
    presenter.show(title: message, variant: variant);
  }

  Future<void> _setEnabled({required BuildContext context, required bool enabled}) async {
    final presenter = PregoPopupAlertPresenter.of(context);
    final failure = enabled ? context.loc.scheduledTaskResumeFailed : context.loc.scheduledTaskPauseFailed;
    if (!await context.read<ScheduledTaskDetailCubit>().setEnabled(enabled: enabled)) {
      presenter.show(title: failure, variant: PregoPopupAlertsNotificationsVariant.error);
    }
  }

  Future<void> _rename({required BuildContext context}) {
    final loc = context.loc;
    final cubit = context.read<ScheduledTaskDetailCubit>();
    return showPregoModal<void>(
      context: context,
      title: loc.scheduledTaskRenameTitle,
      builder: (_) => RenameSheet(
        initialValue: task.definition.name,
        hintText: loc.scheduledTaskRenameHint,
        saveLabel: loc.renameSave,
        failureMessage: loc.scheduledTaskRenameFailed,
        submitOnEnter: true,
        onRename: (name) => cubit.rename(name: name),
      ),
    );
  }

  Future<void> _delete({required BuildContext context}) async {
    final loc = context.loc;
    final presenter = PregoPopupAlertPresenter.of(context);
    final cubit = context.read<ScheduledTaskDetailCubit>();
    final confirmed = await showPregoModal<bool>(
      context: context,
      title: loc.scheduledTaskDeleteTitle(task.definition.name),
      builder: (_) => const _DeleteConfirmation(),
    );
    if (confirmed != true) return;
    if (await cubit.delete()) {
      onDeleted();
    } else {
      presenter.show(title: loc.scheduledTaskDeleteFailed, variant: PregoPopupAlertsNotificationsVariant.error);
    }
  }
}

class const _DeleteConfirmation() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SecondaryText(text: loc.scheduledTaskDeleteMessage),
          const SizedBox(height: PregoSpacing.x2l),
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              label: loc.scheduledTaskDeleteCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
            primary: PregoButtonsSolid(
              key: const Key("scheduled-task-delete-confirm"),
              label: loc.scheduledTaskDeleteConfirm,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              type: PregoButtonsSolidType.destructive,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// The run history, newest first. A new run slides in at the top. A started
/// run opens its session and a failed one a sheet saying why; both carry an
/// arrow. A run whose session was deleted has none, and a tap says so.
class const _History({
  required final ScheduledTask task,
  required final List<ScheduledTaskRun> runs,
  required final bool editable,
  required final VoidCallback onEdit,
  required final OpenScheduledTaskRunSession onOpenSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // The first run replaces "No runs yet" with a cross-fade, not a snap.
    return AnimatedSwitcher(
      duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: runs.isEmpty
          ? PregoGroupedRows(
              key: const ValueKey("no-runs"),
              children: [PregoGroupedRow(icon: TablerRegular.history, title: Text(context.loc.scheduledTaskNoRuns))],
            )
          : _runRows(context: context),
    );
  }

  Widget _runRows({required BuildContext context}) {
    final labels = ScheduledTaskFormatter(loc: context.loc, now: DateTime.now);
    return PregoGroupedRows(
      key: const ValueKey("runs"),
      children: [
        PregoAnimatedList<ScheduledTaskRun>(
          items: runs,
          itemKey: (run) => ValueKey(run.id),
          itemBuilder: (context, index, run) => PregoGroupedRowPosition(
            isLast: index == runs.length - 1,
            child: PregoGroupedRow(
              key: ValueKey("scheduled-task-run-${run.id}"),
              icon: switch (run.outcome) {
                ScheduledTaskRunStarted(late: false) => TablerRegular.circle_check,
                ScheduledTaskRunStarted(late: true) => TablerRegular.clock,
                ScheduledTaskRunSkipped() => TablerRegular.player_track_next,
                ScheduledTaskRunMissed() => TablerRegular.clock_pause,
                ScheduledTaskRunFailed() => TablerRegular.alert_circle,
                ScheduledTaskRunOutcomeUnknown() => TablerRegular.info_circle,
              },
              title: Text(labels.runOutcome(outcome: run.outcome)),
              subtitle: Text(labels.instant(task: task, instant: run.scheduledFor)),
              trailing: switch (run.outcome) {
                ScheduledTaskRunStarted(session: _?) || ScheduledTaskRunFailed() => const Icon(
                  TablerRegular.chevron_right,
                ),
                _ => null,
              },
              onTap: _tapAction(context: context, labels: labels, outcome: run.outcome),
            ),
          ),
        ),
      ],
    );
  }

  /// What a tap on a run row does; null for a row with nothing more to show.
  VoidCallback? _tapAction({
    required BuildContext context,
    required ScheduledTaskFormatter labels,
    required ScheduledTaskRunOutcome outcome,
  }) => switch (outcome) {
    ScheduledTaskRunStarted(session: ScheduledTaskRunSession(:final id, :final projectId)) => () => onOpenSession(
      projectId: projectId,
      projectName: switch (_listedProject(context: context, projectId: projectId)) {
        final project? => projectDisplayName(loc: context.loc, project: project),
        null => null,
      },
      sessionId: id,
    ),
    ScheduledTaskRunStarted() => () => PregoPopupAlertPresenter.of(
      context,
    ).show(title: context.loc.scheduledTaskRunSessionDeleted, variant: PregoPopupAlertsNotificationsVariant.info),
    ScheduledTaskRunFailed(:final reason, :final attempt) => () => unawaited(
      _showFailure(
        context: context,
        details: labels.failureDetails(reason: reason, attempt: attempt),
        canEdit:
            editable &&
            switch (reason) {
              TaskRunFailureReason.projectMissing ||
              TaskRunFailureReason.harnessUnavailable ||
              TaskRunFailureReason.modelUnavailable => true,
              TaskRunFailureReason.startFailed || TaskRunFailureReason.unknown => false,
            },
      ),
    ),
    ScheduledTaskRunSkipped() || ScheduledTaskRunMissed() || ScheduledTaskRunOutcomeUnknown() => null,
  };

  /// [projectId] as this computer lists it, or null while the list loads or
  /// once the project is no longer on it.
  ProjectSummary? _listedProject({required BuildContext context, required String projectId}) =>
      switch (context.read<ProjectListCubit>().state) {
        ProjectListLoaded(:final projects) => projects.where((project) => project.id == projectId).firstOrNull,
        ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
      };

  /// A sheet over the page saying what went wrong and what to do next, offering the editor when that is where the fix is.
  Future<void> _showFailure({
    required BuildContext context,
    required ({String detail, String? nextStep}) details,
    required bool canEdit,
  }) async {
    final edit = await showPregoModal<bool>(
      context: context,
      title: context.loc.scheduledTaskRunFailureTitle,
      builder: (_) => _RunFailureDetails(details: details, canEdit: canEdit),
    );
    if (edit ?? false) onEdit();
  }
}

class const _RunFailureDetails({
  required final ({String detail, String? nextStep}) details,
  required final bool canEdit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final nextStep = details.nextStep;
    final close = PregoButtonsSolid(
      key: const Key("scheduled-task-run-failure-close"),
      label: loc.scheduledTaskRunFailureClose,
      hierarchy: PregoButtonsSolidHierarchy.secondary,
      size: PregoButtonsSolidSize.lg,
      fullWidth: true,
      onPressed: () => context.pop(false),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(details.detail, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
          if (nextStep != null) ...[
            const SizedBox(height: PregoSpacing.sm),
            Text(nextStep, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
          ],
          const SizedBox(height: PregoSpacing.x2l),
          if (canEdit)
            PregoSheetActions(
              secondary: close,
              primary: PregoButtonsSolid(
                key: const Key("scheduled-task-run-failure-edit"),
                label: loc.scheduledTaskEditTitle,
                hierarchy: PregoButtonsSolidHierarchy.primary,
                size: PregoButtonsSolidSize.lg,
                fullWidth: true,
                onPressed: () => context.pop(true),
              ),
            )
          else
            close,
        ],
      ),
    );
  }
}

class const _SecondaryText({required final String text}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
  );
}
