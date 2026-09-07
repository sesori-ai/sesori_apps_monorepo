import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";

import "catalog_scan_row_playbook.dart";

/// Direct native entrypoint; Widgetbook also exposes this same preview.
void main() => runApp(
  CatalogScanRowMotionPreview(
    designSystem: PregoDesignSystem.dark,
    reducedMotion: false,
  ),
);
