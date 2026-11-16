import "dart:async";

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

/// Asks before a send that will archive a pinned session. False keeps the
/// send sheet open.
typedef PinnedArchiveConfirmation = Future<bool> Function({required BuildContext context});

/// Asks where to send [source]: a bottom sheet under touch, a dialog under a
/// pointer. Null when the user leaves without sending.
Future<SendSessionChoice?> showSendSessionSheet({
  required BuildContext context,
  required Session source,
  required SessionActionsCubit actions,
  required SessionSearchCubitFactory createSearch,
  required PinnedArchiveConfirmation confirmPinnedArchive,
}) async {
  // The sheet's route sits above the session scope, so its owners are read here.
  final window = context.read<SessionWindowService>();
  final projectInventory = context.read<ProjectInventoryService>();
  // Read before the sheet opens, so its switch never flips while it slides in.
  final archiveAfterSending = await actions.archiveAfterSend();
  if (!context.mounted) return null;
  return await showPregoModal<SendSessionChoice>(
    context: context,
    title: context.loc.sendSessionTitle,
    builder: (_) => BlocProvider(
      // Created with the sheet, so the picker opens on loaded sessions.
      create: (_) => createSearch(window: window, projectInventory: projectInventory, excludedSessionId: source.id),
      child: _SendSessionSheet(
        source: source,
        actions: actions,
        initialArchiveAfterSending: archiveAfterSending,
        confirmPinnedArchive: confirmPinnedArchive,
      ),
    ),
  );
}

class const _SendSessionSheet({
  required final Session source,
  required final SessionActionsCubit actions,
  required final bool initialArchiveAfterSending,
  required final PinnedArchiveConfirmation confirmPinnedArchive,
}) extends StatefulWidget {
  @override
  State<_SendSessionSheet> createState() => _SendSessionSheetState();
}

class _SendSessionSheetState() extends State<_SendSessionSheet> {
  static const double _targetMaxWidth = 220;

  SessionSearchMatch? _target;

  late bool _archiveAfterSending = widget.initialArchiveAfterSending;

  /// The next send opens with the same choice.
  void _setArchiveAfterSending({required bool value}) {
    setState(() => _archiveAfterSending = value);
    unawaited(widget.actions.setArchiveAfterSend(value: value));
  }

  /// A pinned source is asked about here, next to the tap, rather than once
  /// the summary lands; the archive after the send then doesn't ask again.
  Future<void> _send({required SessionSearchMatch target}) async {
    final archive = _archiveAfterSending;
    if (archive && widget.source.pinned && !await widget.confirmPinnedArchive(context: context)) return;
    if (!mounted) return;
    context.pop<SendSessionChoice>((target: target, archiveAfterSending: archive));
  }

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
                    onChanged: (value) => _setArchiveAfterSending(value: value),
                  ),
                  onTap: () => _setArchiveAfterSending(value: !_archiveAfterSending),
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
              final target => () => unawaited(_send(target: target)),
            },
          ),
        ],
      ),
    );
  }
}
