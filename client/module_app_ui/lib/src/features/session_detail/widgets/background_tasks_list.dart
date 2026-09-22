import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "background_task_row.dart";

/// The scrollable list of sub-agent rows under the list heading. It needs a
/// bounded height: given less than it wants, it scrolls in what it gets.
class const BackgroundTasksList({
  super.key,
  required final String? projectId,
  required final List<Session> tasks,
  required final Map<String, SessionStatus> childStatuses,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PregoDivider(flat: true),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final child = tasks[index];
                return BackgroundTaskRow(
                  projectId: projectId,
                  session: child,
                  status: childStatuses[child.id],
                  isLast: index == tasks.length - 1,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
