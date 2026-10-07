import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

const double _statusSlotSize = 16;

/// One session in a list that mixes projects: an amber dot and "Waiting" while
/// it waits for the user, a rotating sparkle while it runs, a resting one while
/// it is unread, its project under the title and when it last changed at the
/// end.
class const ActivityTile({
  super.key,
  required final SessionActivityEntry entry,
  required final String projectName,
  required final VoidCallback onOpen,
}) extends StatelessWidget {
  static const double _waitingDotSize = 8;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final session = entry.session;
    final updatedAt = session.time?.updated;
    return _ActivityRow(
      onTap: onOpen,
      status: switch (entry) {
        SessionActivityEntry(isAwaitingInput: true) => Semantics(
          label: loc.sessionListAwaitingInput,
          child: Container(
            width: _waitingDotSize,
            height: _waitingDotSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: prego.colors.fgWarningPrimary),
          ),
        ),
        SessionActivityEntry(isRunning: true) => Semantics(
          label: loc.sessionListRunning,
          child: const PregoAiLoader(size: _statusSlotSize),
        ),
        SessionActivityEntry(isUnseen: true) => Semantics(
          label: loc.sessionListNewActivity,
          child: const PregoAiLoader(size: _statusSlotSize, animate: false),
        ),
        SessionActivityEntry() => null,
      },
      title: session.title ?? loc.sessionListUntitled,
      meta: [
        if (entry.isAwaitingInput) ...[
          // The dot already speaks the waiting state.
          TextSpan(
            text: loc.sessionListWaiting,
            style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textWarningPrimary),
            semanticsLabel: "",
          ),
          const TextSpan(text: " · ", semanticsLabel: ""),
        ],
        TextSpan(text: projectName),
      ],
      trailing: updatedAt == null
          ? null
          : Text(
              context.formatTimestampCompact(ms: updatedAt),
              semanticsLabel: context.formatTimestamp(updatedAt),
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
              maxLines: 1,
              softWrap: false,
            ),
    );
  }
}

/// A new session the bridge is still creating, in [ActivityTile]'s geometry so
/// the real row takes its place without moving anything: the running sparkle,
/// the first line of the first message, "Creating…" before the harness and the
/// project, and no time.
///
/// A tap shows the alert that the session cannot be opened yet.
class const PendingActivityTile({
  super.key,
  required final LaunchingSession launch,
  required final String projectName,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return _ActivityRow(
      onTap: () => PregoPopupAlertPresenter.of(context).show(title: loc.sessionListLaunchingAlert),
      // "Creating…" already says what the sparkle means.
      status: const ExcludeSemantics(child: PregoAiLoader(size: _statusSlotSize)),
      title: launch.title ?? loc.sessionListUntitled,
      meta: [
        TextSpan(text: "${loc.sessionListCreating} · ${PregoBrandLogo.displayNameFor(launch.pluginId)} · $projectName"),
      ],
      trailing: null,
    );
  }
}

class const _ActivityRow({
  required final VoidCallback onTap,
  required final Widget? status,
  required final String title,
  required final List<InlineSpan> meta,
  required final Widget? trailing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl, vertical: PregoSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PregoSpacing.xs,
              children: [
                SizedBox.square(
                  dimension: _statusSlotSize,
                  child: Center(child: status),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PregoSpacing.xxs,
                    children: [
                      Text(
                        title,
                        style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text.rich(
                        TextSpan(children: meta),
                        style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
