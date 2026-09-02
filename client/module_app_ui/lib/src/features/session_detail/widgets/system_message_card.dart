import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "assistant_message_card.dart";

/// A neutral inline surface for transcript messages authored by automation.
class const SystemMessageCard({
  super.key,
  required final String? projectId,
  required final MessageWithParts message,
  required final Map<String, String> streamingText,
  required final List<Session> children,
  required final Map<String, SessionStatus> childStatuses,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PregoSpacing.xl,
        vertical: PregoSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: prego.colors.bgSecondary,
          border: Border.all(color: prego.colors.borderSecondary),
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PregoTag(
                icon: TablerRegular.robot,
                label: context.loc.sessionDetailAutomation,
              ),
              const SizedBox(height: PregoSpacing.md),
              AssistantMessageCard(
                projectId: projectId,
                message: message,
                streamingText: streamingText,
                children: children,
                childStatuses: childStatuses,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
