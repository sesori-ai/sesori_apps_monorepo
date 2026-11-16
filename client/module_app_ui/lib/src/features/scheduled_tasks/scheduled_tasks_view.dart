import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/bridge_update_sheet.dart";
import "../session_list/session_list_headings.dart";
import "scheduled_task_formatter.dart";

/// How a Scheduled page is left: [back] for a page pushed like the other
/// Settings pages, [close] for a page shown over another.
enum ScheduledPageExit() {
  back,
  close,
}

/// The current computer's scheduled tasks under Recurring, then Once. A
/// heading shows only while it has tasks; rows enter and leave in place, so
/// a paused or deleted task never makes the list jump. The product shell owns
/// the cubit's dependencies and the routes.
class const ScheduledTasksView({
  super.key,
  required final ScheduledTasksCubit Function() createCubit,
  required final ScheduledPageExit exit,
  required final VoidCallback onExit,
  required final void Function({required String taskId}) onOpenTask,

  /// Opens the New task screen.
  required final VoidCallback onNewTask,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createCubit(),
    child: Builder(
      builder: (context) => PregoGlassScaffold(
        title: context.loc.scheduledTasksTitle,
        titleMode: PregoTopNavigationTitleMode.inline,
        onBack: switch (exit) {
          ScheduledPageExit.back => onExit,
          ScheduledPageExit.close => null,
        },
        automaticallyImplyLeading: false,
        actions: [
          PregoButtonsIconGlass(
            key: const Key("scheduled-tasks-new"),
            icon: TablerRegular.plus,
            semanticLabel: context.loc.scheduledTaskNew,
            // An older computer cannot take a task; the tap says how to update it.
            onPressed: () => context.read<ScheduledTasksCubit>().state is ScheduledTasksBridgeOutdated
                ? unawaited(showBridgeUpdateSheet(context: context))
                : onNewTask(),
          ),
          if (exit == ScheduledPageExit.close)
            PregoButtonsIconGlass(
              icon: TablerRegular.x,
              semanticLabel: context.loc.scheduledTasksClose,
              onPressed: onExit,
            ),
        ],
        onRefresh: () => context.read<ScheduledTasksCubit>().refresh(),
        slivers: [_Body(onOpenTask: onOpenTask)],
        titleKeptSuffix: null,
      ),
    ),
  );
}

class const _Body({required final void Function({required String taskId}) onOpenTask}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return SliverPadding(
      padding: EdgeInsetsDirectional.fromSTEB(
        PregoSpacing.xl,
        0,
        PregoSpacing.xl,
        PregoSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      sliver: switch (context.watch<ScheduledTasksCubit>().state) {
        ScheduledTasksLoading() => const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: PregoActivityIndicator(color: null)),
        ),
        ScheduledTasksFailed() => SliverToBoxAdapter(
          child: ScheduledTaskStatusRow(
            key: const Key("scheduled-tasks-failed"),
            icon: TablerRegular.alert_circle,
            title: loc.scheduledTasksLoadFailed,
            trailing: PregoButtonsSolid(
              label: loc.scheduledTasksRetry,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.sm,
              onPressed: () => unawaited(context.read<ScheduledTasksCubit>().retry()),
            ),
            onTap: null,
          ),
        ),
        ScheduledTasksBridgeOutdated() => const SliverToBoxAdapter(child: ScheduledTasksBridgeOutdatedRow()),
        // The list stays mounted when the last task leaves, so its row and
        // heading collapse before the empty text fades in.
        ScheduledTasksLoaded(:final recurring, :final once) => SliverMainAxisGroup(
          slivers: [
            _TaskList(
              entries: [
                if (recurring.isNotEmpty) _HeadingEntry(heading: loc.scheduledTasksRecurringHeading),
                for (final task in recurring) _TaskEntry(task: task, isRecurring: true),
                if (once.isNotEmpty) _HeadingEntry(heading: loc.scheduledTasksOnceHeading),
                for (final task in once) _TaskEntry(task: task, isRecurring: false),
              ],
              onOpenTask: onOpenTask,
            ),
            if (recurring.isEmpty && once.isEmpty) const SliverFillRemaining(hasScrollBody: false, child: _EmptyText()),
          ],
        ),
      },
    );
  }
}

/// Fades in once departing rows have had time to collapse.
class const _EmptyText() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration * 2,
    curve: const Interval(0.5, 1),
    builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
    child: Center(
      child: Text(
        context.loc.scheduledTasksEmpty,
        key: const Key("scheduled-tasks-empty"),
        textAlign: TextAlign.center,
        style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
      ),
    ),
  );
}

sealed class const _Entry();

final class const _HeadingEntry({required final String heading}) extends _Entry;

final class const _TaskEntry({required final ScheduledTask task, required final bool isRecurring}) extends _Entry;

class const _TaskList({
  required final List<_Entry> entries,
  required final void Function({required String taskId}) onOpenTask,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoAnimatedSliverList<_Entry>(
    items: entries,
    slidesWhenMoved: (_) => false,
    itemKey: (entry) => switch (entry) {
      // A task moving between headings is a new row there.
      _HeadingEntry(:final heading) => ValueKey("heading-$heading"),
      _TaskEntry(:final task, :final isRecurring) => ValueKey("task-${task.id}-$isRecurring"),
    },
    itemBuilder: (context, index, entry) => switch (entry) {
      _HeadingEntry(:final heading) => SessionListHeading(heading: heading, isFirst: index == 0),
      _TaskEntry(:final task, :final isRecurring) => PregoGroupedRowPosition(
        isLast: index == entries.length - 1 || entries[index + 1] is _HeadingEntry,
        child: _TaskRow(task: task, isRecurring: isRecurring, onOpenTask: onOpenTask),
      ),
    },
  );
}

class const _TaskRow({
  required final ScheduledTask task,
  required final bool isRecurring,
  required final void Function({required String taskId}) onOpenTask,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final labels = ScheduledTaskFormatter(loc: loc, now: DateTime.now);
    return PregoGroupedRow(
      key: ValueKey("scheduled-task-row-${task.id}"),
      icon: isRecurring ? TablerRegular.repeat : TablerRegular.clock,
      title: Text(task.definition.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        isRecurring
            ? labels.schedule(task: task)
            : switch (task.nextRunAt) {
                final next? when task.enabled => labels.instant(task: task, instant: next),
                _ => loc.scheduledTaskPaused,
              },
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isRecurring
          ? PregoSwitch(
              key: ValueKey("scheduled-task-switch-${task.id}"),
              value: task.enabled,
              onChanged: (enabled) => unawaited(_setEnabled(context: context, enabled: enabled)),
            )
          : const Icon(TablerRegular.chevron_right),
      onTap: () => onOpenTask(taskId: task.id),
    );
  }

  Future<void> _setEnabled({required BuildContext context, required bool enabled}) async {
    final presenter = PregoPopupAlertPresenter.of(context);
    final message = context.loc.scheduledTasksToggleFailed(task.definition.name);
    final changed = await context.read<ScheduledTasksCubit>().setEnabled(taskId: task.id, enabled: enabled);
    if (!changed) presenter.show(title: message, variant: PregoPopupAlertsNotificationsVariant.error);
  }
}

/// The row an older computer shows instead of its tasks. A tap opens the
/// steps to update it.
class const ScheduledTasksBridgeOutdatedRow({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScheduledTaskStatusRow(
    key: const Key("scheduled-tasks-bridge-outdated"),
    icon: TablerRegular.download,
    title: context.loc.scheduledTasksBridgeOutdated,
    trailing: const Icon(TablerRegular.chevron_right),
    onTap: () => unawaited(showBridgeUpdateSheet(context: context)),
  );
}

/// One row in its own card, for a page's loading failure or older computer.
class const ScheduledTaskStatusRow({
  super.key,
  required final IconData icon,
  required final String title,
  required final Widget trailing,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: PregoSpacing.md),
    child: PregoGroupedRows(
      children: [
        PregoGroupedRow(icon: icon, title: Text(title), trailing: trailing, onTap: onTap),
      ],
    ),
  );
}
