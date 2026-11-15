import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../session_picker/session_picker.dart";

/// Builds the session search behind the send sheet's picker, which never
/// lists [excludedSessionId].
typedef SessionSearchCubitFactory = SessionSearchCubit Function({
  required SessionWindowService window,
  required ProjectInventoryService projectInventory,
  required String? excludedSessionId,
});

/// What the user chose to send [source] into.
typedef SendSessionChoice = ({SessionSearchMatch target, bool archiveAfterSending});

/// Asks where to send [source]: a bottom sheet under touch, a dialog under a
/// pointer. Null when the user leaves without sending.
Future<SendSessionChoice?> showSendSessionSheet({
  required BuildContext context,
  required Session source,
  required SessionSearchCubitFactory createSearch,
}) {
  // The sheet's route sits above the session scope, so its owners are read here.
  final window = context.read<SessionWindowService>();
  final projectInventory = context.read<ProjectInventoryService>();
  return showPregoModal<SendSessionChoice>(
    context: context,
    title: context.loc.sendSessionTitle,
    builder: (_) => BlocProvider(
      // Created with the sheet, so the picker opens on loaded sessions.
      create: (_) => createSearch(window: window, projectInventory: projectInventory, excludedSessionId: source.id),
      child: const _SendSessionSheet(),
    ),
  );
}

class const _SendSessionSheet() extends StatefulWidget {
  @override
  State<_SendSessionSheet> createState() => _SendSessionSheetState();
}

class _SendSessionSheetState() extends State<_SendSessionSheet> {
  static const double _targetMaxWidth = 220;

  SessionSearchMatch? _target;

  // ponytail: resets to on each time the sheet opens; step 9 archives with it and keeps the last choice.
  bool _archiveAfterSending = true;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final target = _target;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PregoGroupedRows(
            children: [
              SessionPicker(
                selectedSessionId: target?.session.id,
                onSelected: ({required target}) => setState(() => _target = target),
                triggerBuilder: (context, open) => PregoGroupedRow(
                  key: const Key("send_session_target"),
                  title: Text(loc.sendSessionTo),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _targetMaxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: PregoSpacing.xs,
                      children: [
                        Flexible(
                          child: Text(
                            switch (target) {
                              null => loc.sendSessionChooseTarget,
                              final target => target.session.title ?? loc.sessionListUntitled,
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: prego.textTheme.textMd.regular.copyWith(
                              color: target == null ? prego.colors.textTertiary : prego.colors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(TablerRegular.chevron_right),
                      ],
                    ),
                  ),
                  onTap: open,
                ),
              ),
              MergeSemantics(
                child: PregoGroupedRow(
                  key: const Key("send_session_archive_after"),
                  title: Text(loc.sendSessionArchiveAfter),
                  trailing: PregoSwitch(
                    value: _archiveAfterSending,
                    onChanged: (value) => setState(() => _archiveAfterSending = value),
                  ),
                  onTap: () => setState(() => _archiveAfterSending = !_archiveAfterSending),
                ),
              ),
            ],
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            key: const Key("send_session_send"),
            label: loc.sendSessionSend,
            hierarchy: PregoButtonsSolidHierarchy.primary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: switch (target) {
              null => null,
              final target => () => context.pop<SendSessionChoice>((
                target: target,
                archiveAfterSending: _archiveAfterSending,
              )),
            },
          ),
        ],
      ),
    );
  }
}
