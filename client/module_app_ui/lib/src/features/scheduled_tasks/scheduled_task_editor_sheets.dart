import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "../session_list/session_list_headings.dart";
import "scheduled_task_formatter.dart";

/// Opens the When sheet over the task editor. Each choice applies at once, so
/// the When line behind follows it.
Future<void> showScheduledTaskWhenSheet({required BuildContext context}) {
  final cubit = context.read<ScheduledTaskEditorCubit>();
  return showPregoModal<void>(
    context: context,
    title: context.loc.scheduledTaskWhen,
    builder: (_) => BlocProvider.value(value: cubit, child: const _WhenSheet()),
  );
}

/// Opens the Each run sheet over the task editor, applying each choice at once.
Future<void> showScheduledTaskEachRunSheet({required BuildContext context}) {
  final cubit = context.read<ScheduledTaskEditorCubit>();
  return showPregoModal<void>(
    context: context,
    title: context.loc.scheduledTaskEachRun,
    builder: (_) => BlocProvider.value(value: cubit, child: const _EachRunSheet()),
  );
}

ScheduledTaskEditorReady? _readyOf(ScheduledTaskEditorState state) => switch (state) {
  final ScheduledTaskEditorReady ready => ready,
  ScheduledTaskEditorLoading() || ScheduledTaskEditorUnavailable() => null,
};

/// A sheet's content, growing and shrinking with its choices rather than
/// snapping to a new height.
class const _SheetBody({required final List<Widget> children}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
    child: AnimatedSize(
      duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

class const _WhenSheet() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ScheduledTaskEditorCubit>();
    final ready = _readyOf(cubit.state);
    if (ready == null) return const SizedBox.shrink();
    final loc = context.loc;
    final labels = ScheduledTaskFormatter(loc: loc, now: DateTime.now);
    final schedule = ready.schedule;
    return _SheetBody(
      children: [
        PregoGroupedRows(
          children: [
            for (final repeat in ScheduledTaskRepeat.values)
              _ChoiceRow(
                key: ValueKey("scheduled-task-repeat-${repeat.name}"),
                label: _repeatLabel(loc: loc, repeat: repeat),
                selected: ready.repeat == repeat,
                onTap: () => cubit.selectRepeat(repeat: repeat),
              ),
          ],
        ),
        const SizedBox(height: PregoSpacing.xl),
        PregoGroupedRows(
          children: switch (schedule) {
            TaskScheduleOnce(:final at) => [
              PregoDateTimeField(
                key: const Key("scheduled-task-once-at"),
                icon: TablerRegular.calendar,
                label: loc.scheduledTaskDateAndTime,
                valueLabel: labels.localDateTime(at: at),
                value: _dateTimeOf(at),
                mode: PregoDateTimeFieldMode.dateAndTime,
                // A one-off time that has passed cannot be picked.
                minimum: cubit.zoneNow,
                onChanged: (moment) => cubit.setDateTime(at: _localOf(moment)),
              ),
            ],
            TaskScheduleDaily(:final time) || TaskScheduleWeekdays(:final time) || TaskScheduleWeekly(:final time) => [
              _TimeField(
                time: time,
                label: loc.scheduledTaskTime,
                valueLabel: labels.timeOfDay(time: time),
              ),
            ],
            TaskScheduleEveryHours(:final hours, :final start) => [
              _HoursRow(hours: hours),
              PregoDateTimeField(
                key: const Key("scheduled-task-interval-start"),
                icon: TablerRegular.clock_play,
                label: loc.scheduledTaskStarting,
                valueLabel: labels.localDateTime(at: start),
                value: _dateTimeOf(start),
                mode: PregoDateTimeFieldMode.dateAndTime,
                minimum: null,
                onChanged: (moment) => cubit.setDateTime(at: _localOf(moment)),
              ),
            ],
            TaskScheduleUnknown() => const [],
          },
        ),
        if (schedule case TaskScheduleWeekly(:final days)) ...[
          const SizedBox(height: PregoSpacing.md),
          _Weekdays(days: days, labels: labels),
        ],
        if (ready.offersMissedRunChoice) ...[
          SessionListHeading(heading: loc.scheduledTaskMissedHeading, isFirst: false),
          PregoGroupedRows(
            children: [
              _ChoiceRow(
                key: const Key("scheduled-task-run-when-back"),
                label: loc.scheduledTaskRunWhenBack,
                selected: ready.missedRunPolicy != TaskMissedRunPolicy.waitForNext,
                onTap: () => cubit.setMissedRunPolicy(policy: TaskMissedRunPolicy.runWhenBack),
              ),
              _ChoiceRow(
                key: const Key("scheduled-task-wait-for-next"),
                label: loc.scheduledTaskWaitForNext,
                selected: ready.missedRunPolicy == TaskMissedRunPolicy.waitForNext,
                onTap: () => cubit.setMissedRunPolicy(policy: TaskMissedRunPolicy.waitForNext),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _repeatLabel({required AppLocalizations loc, required ScheduledTaskRepeat repeat}) => switch (repeat) {
    ScheduledTaskRepeat.once => loc.scheduledTaskRepeatOnce,
    ScheduledTaskRepeat.daily => loc.scheduledTaskRepeatDaily,
    ScheduledTaskRepeat.weekdays => loc.scheduledTaskRepeatWeekdays,
    ScheduledTaskRepeat.weekly => loc.scheduledTaskRepeatWeekly,
    ScheduledTaskRepeat.everyHours => loc.scheduledTaskRepeatEveryHours,
  };

  static DateTime _dateTimeOf(TaskLocalDateTime at) => DateTime(at.year, at.month, at.day, at.hour, at.minute);

  static TaskLocalDateTime _localOf(DateTime moment) => TaskLocalDateTime(
    year: moment.year,
    month: moment.month,
    day: moment.day,
    hour: moment.hour,
    minute: moment.minute,
  );
}

class const _TimeField({
  required final TaskTimeOfDay time,
  required final String label,
  required final String valueLabel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoDateTimeField(
    key: const Key("scheduled-task-time"),
    icon: TablerRegular.clock,
    label: label,
    valueLabel: valueLabel,
    value: DateTime(2000, 1, 1, time.hour, time.minute),
    mode: PregoDateTimeFieldMode.time,
    minimum: null,
    onChanged: (moment) => context.read<ScheduledTaskEditorCubit>().setTime(
      time: TaskTimeOfDay(hour: moment.hour, minute: moment.minute),
    ),
  );
}

/// The Every few hours interval, stepped within the cubit's bounds.
class const _HoursRow({required final int hours}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.read<ScheduledTaskEditorCubit>();
    return PregoGroupedRow(
      key: const Key("scheduled-task-hours"),
      icon: TablerRegular.repeat,
      title: Text(loc.scheduledTaskEveryHours(hours)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.sm,
        children: [
          PregoButtonsSolid.iconOnly(
            key: const Key("scheduled-task-fewer-hours"),
            leadingIcon: TablerRegular.minus,
            semanticLabel: loc.scheduledTaskFewerHours,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: hours > ScheduledTaskEditorCubit.minHours ? () => cubit.setHours(hours: hours - 1) : null,
          ),
          PregoButtonsSolid.iconOnly(
            key: const Key("scheduled-task-more-hours"),
            leadingIcon: TablerRegular.plus,
            semanticLabel: loc.scheduledTaskMoreHours,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: hours < ScheduledTaskEditorCubit.maxHours ? () => cubit.setHours(hours: hours + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// A weekly task's days, each a toggle, all seven on one row.
class const _Weekdays({required final Set<TaskWeekday> days, required final ScheduledTaskFormatter labels})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: PregoSpacing.xs,
    children: [
      for (final day in TaskWeekday.values)
        Expanded(
          child: Semantics(
            label: labels.weekdayName(day: day),
            selected: days.contains(day),
            button: true,
            excludeSemantics: true,
            child: PregoButtonsSolid(
              key: ValueKey("scheduled-task-day-${day.name}"),
              label: labels.weekdayInitial(day: day),
              hierarchy: days.contains(day) ? PregoButtonsSolidHierarchy.primary : PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.sm,
              fullWidth: true,
              onPressed: () => context.read<ScheduledTaskEditorCubit>().toggleWeekday(day: day),
            ),
          ),
        ),
    ],
  );
}

class const _EachRunSheet() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ScheduledTaskEditorCubit>();
    final ready = _readyOf(cubit.state);
    if (ready == null) return const SizedBox.shrink();
    final loc = context.loc;
    final sameSession = ready.runMode is TaskRunModeSameSession;
    final approveAll = ready.approvalMode == TaskApprovalMode.approveAll;
    return _SheetBody(
      children: [
        PregoGroupedRows(
          children: [
            _ChoiceRow(
              key: const Key("scheduled-task-new-session"),
              label: loc.scheduledTaskStartsNewSession,
              selected: !sameSession,
              onTap: () => cubit.setSameSession(sameSession: false),
            ),
            _ChoiceRow(
              key: const Key("scheduled-task-same-session"),
              label: loc.scheduledTaskContinuesSession,
              selected: sameSession,
              onTap: () => cubit.setSameSession(sameSession: true),
            ),
            // Step 11 adds the auto-compact switch here, under Continue.
          ],
        ),
        SessionListHeading(heading: loc.scheduledTaskApprovalsHeading, isFirst: false),
        PregoGroupedRows(
          children: [
            _ChoiceRow(
              key: const Key("scheduled-task-approvals-ask"),
              label: loc.scheduledTaskApprovalsAsk,
              selected: !approveAll,
              onTap: () => cubit.setApprovalMode(mode: TaskApprovalMode.ask),
            ),
            _ChoiceRow(
              key: const Key("scheduled-task-approvals-all"),
              label: loc.scheduledTaskApprovalsAll,
              selected: approveAll,
              onTap: () => cubit.setApprovalMode(mode: TaskApprovalMode.approveAll),
            ),
          ],
        ),
      ],
    );
  }
}

/// One of a sheet's exclusive choices, checked when [selected].
class const _ChoiceRow({
  super.key,
  required final String label,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: PregoGroupedRow(
      title: Text(label),
      trailing: selected
          ? Icon(TablerRegular.check, size: PregoIconSize.sm, color: context.prego.colors.bgBrandSolid)
          : null,
      onTap: onTap,
    ),
  );
}
