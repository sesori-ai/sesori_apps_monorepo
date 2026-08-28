import "package:material_ui/material_ui.dart";

import "prego_grouped_rows.dart";

class const PregoGroupedNoticeRow({
  required final IconData icon,
  required final Widget title,
  final Widget? subtitle,
  final Widget? trailing,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [PregoGroupedRow(icon: icon, title: title, subtitle: subtitle, trailing: trailing)],
    );
  }
}
