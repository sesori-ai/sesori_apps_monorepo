import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Over the composer while it holds an edit of an earlier message: what
/// Resend will do, and Cancel, which gives the composer back what it held.
class const EditMessageBanner({
  super.key,
  required final SessionComposerEditing editing,
  required final VoidCallback onCancel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final secondary = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(TablerRegular.pencil, size: 16, color: prego.colors.fgBrandPrimary),
          ),
          const SizedBox(width: PregoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (editing.phase) {
                    SessionEditPhase.restoring || SessionEditPhase.composing => loc.sessionDetailEditBannerTitle,
                    SessionEditPhase.stopping => loc.sessionDetailEditBannerStopping,
                    SessionEditPhase.sending => loc.sessionDetailEditBannerSending,
                  },
                  style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
                ),
                Text(loc.sessionDetailEditBannerBody, style: secondary),
                if (editing.leftOutCount > 0)
                  Text(loc.sessionDetailEditBannerLeftOut(editing.leftOutCount), style: secondary),
              ],
            ),
          ),
          PregoButtonsSolid(
            key: const Key("edit_message_cancel"),
            label: loc.sessionDetailEditCancel,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.sm,
            // A sent edit cannot be called back.
            onPressed: editing.phase == SessionEditPhase.sending ? null : onCancel,
          ),
        ],
      ),
    );
  }
}
