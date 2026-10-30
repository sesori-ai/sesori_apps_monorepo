import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// Invites the user to book a call with the CEO, in [copy]'s wording or the
/// built-in one. Resolves true when the user chose to book.
Future<bool> showFounderCallSheet({required BuildContext context, required FounderCallCopy copy}) async {
  final book = await showPregoModal<bool>(
    context: context,
    title: copy.title ?? context.loc.founderCallTitle,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.message ?? context.loc.founderCallMessage,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            key: const Key("founder_call_book"),
            label: copy.buttonLabel ?? context.loc.founderCallBook,
            hierarchy: PregoButtonsSolidHierarchy.primary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route showPregoModal pushed
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            key: const Key("founder_call_not_now"),
            label: context.loc.founderCallNotNow,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route showPregoModal pushed
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    ),
  );
  return book ?? false;
}
