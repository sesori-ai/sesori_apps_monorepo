import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

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
  static const double _statusSlotSize = 16;
  static const double _waitingDotSize = 8;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final session = entry.session;
    final meta = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary);
    final updatedAt = session.time?.updated;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl, vertical: PregoSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PregoSpacing.xs,
              children: [
                SizedBox.square(
                  dimension: _statusSlotSize,
                  child: Center(
                    child: switch (entry) {
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
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PregoSpacing.xxs,
                    children: [
                      Text(
                        session.title ?? loc.sessionListUntitled,
                        style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
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
                        ),
                        style: meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (updatedAt != null)
                  Text(
                    context.formatTimestampCompact(ms: updatedAt),
                    semanticsLabel: context.formatTimestamp(updatedAt),
                    style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                    maxLines: 1,
                    softWrap: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
