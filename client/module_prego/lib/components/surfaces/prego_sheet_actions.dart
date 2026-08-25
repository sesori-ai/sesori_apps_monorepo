import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

class const PregoSheetActions({
  required final Widget secondary,
  required final Widget primary,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: PregoSpacing.md),
        Expanded(child: primary),
      ],
    );
  }
}
