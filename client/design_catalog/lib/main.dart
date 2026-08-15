import "package:flutter/widgets.dart";
import "package:widgetbook/widgetbook.dart";

import "src/prego_button_catalog.dart";
import "src/prego_catalog_background.dart";
import "src/prego_catalog_layout_guides.dart";
import "src/prego_catalog_platform.dart";
import "src/prego_catalog_theme.dart";
import "src/prego_catalog_viewports.dart";
import "src/review_tools/prego_review_tools.dart";

void main() {
  runApp(const DesignCatalogApp());
}

const _catalogHeader = "Sesori design catalog";

/// Interactive, dependency-light catalog for Sesori's production components.
class const DesignCatalogApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      appBuilder: buildPregoCatalogApp,
      addons: [
        buildPregoThemeAddon(),
        PregoReviewToolsAddon(),
        ViewportAddon(PregoCatalogViewports.all),
        PregoCatalogPlatformAddon(viewports: PregoCatalogViewports.all),
        PregoCanvasBackgroundAddon(),
        AlignmentAddon(),
        TextScaleAddon(min: 1, max: 2),
        // ignore: experimental_member_use, Widgetbook 3.25 marks this audit addon experimental
        SemanticsAddon(),
        BuilderAddon(
          name: "Prego review surface",
          builder: (context, child) => buildPregoReviewSurface(context, child: child),
        ),
        PregoLayoutGuidesAddon(),
        // ignore: experimental_member_use, Widgetbook 3.25 marks this audit addon experimental
        TimeDilationAddon(),
      ],
      directories: [
        WidgetbookFolder(
          name: "Prego",
          isInitiallyExpanded: true,
          children: [buildPregoSolidButtonComponent()],
        ),
      ],
      header: const Text(_catalogHeader),
      headerPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
    );
  }
}
