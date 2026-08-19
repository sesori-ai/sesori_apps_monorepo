import "dart:async";

import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/module_prego.dart";

class const PregoReviewAction({
  required final String label,
  required final String text,
  required final FutureOr<void> Function()? onPressed,
  final bool wide = false,
  final Color? foregroundColor,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final button = material.TextButton(
      onPressed: onPressed,
      style: material.TextButton.styleFrom(
        foregroundColor: foregroundColor ?? colors.textPrimary,
        disabledForegroundColor: colors.textDisabled,
        backgroundColor: colors.bgSurface2,
        disabledBackgroundColor: colors.bgDisabledSubtle,
        minimumSize: const Size(28, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: material.MaterialTapTargetSize.shrinkWrap,
        textStyle: context.prego.textTheme.textXs.medium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.md)),
        side: BorderSide(color: onPressed == null ? colors.borderDisabled : colors.borderSecondary),
      ),
      child: ExcludeSemantics(
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    return Semantics(
      label: label,
      child: wide ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
