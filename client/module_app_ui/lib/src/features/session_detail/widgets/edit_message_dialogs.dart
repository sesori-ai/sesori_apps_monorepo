import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Explains why Edit and resend cannot start from a message, so the tap is
/// answered rather than ignored.
Future<void> showEditUnavailableDialog({
  required BuildContext context,
  required MessageEditRefusal refusal,
}) {
  final loc = context.loc;
  final (title, body) = switch (refusal) {
    MessageEditRefusal.sentMidTurn => (loc.sessionDetailEditMidTurnTitle, loc.sessionDetailEditMidTurnBody),
    MessageEditRefusal.command => (loc.sessionDetailEditCommandTitle, loc.sessionDetailEditCommandBody),
  };
  return showPregoModal<void>(
    context: context,
    title: title,
    builder: (sheetContext) => _DialogBody(
      body: body,
      buttons: [
        PregoButtonsSolid(
          key: const Key("edit_unavailable_ok"),
          label: loc.sessionDetailEditUnavailableOk,
          hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
          size: PregoButtonsSolidSize.xl,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    ),
  );
}

/// Asks whether to stop the running turn so the edit can go. True for Stop
/// and resend.
Future<bool?> showEditBusyDialog({required BuildContext context}) {
  final loc = context.loc;
  return showPregoModal<bool>(
    context: context,
    title: loc.sessionDetailEditBusyTitle,
    builder: (sheetContext) => _DialogBody(
      body: loc.sessionDetailEditBusyBody,
      buttons: [
        PregoButtonsSolid(
          key: const Key("edit_busy_stop_and_resend"),
          label: loc.sessionDetailEditStopAndResend,
          hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
          size: PregoButtonsSolidSize.xl,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        const SizedBox(height: PregoSpacing.md),
        PregoButtonsSolid(
          key: const Key("edit_busy_cancel"),
          label: loc.sessionDetailEditCancel,
          hierarchy: PregoButtonsSolidHierarchy.tertiary,
          size: PregoButtonsSolidSize.xl,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
}

class const _DialogBody({required final String body, required final List<Widget> buttons}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
          const SizedBox(height: PregoSpacing.x2l),
          ...buttons,
        ],
      ),
    );
  }
}
