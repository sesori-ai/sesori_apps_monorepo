import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:widgetbook/widgetbook.dart";

/// Copies Widgetbook's simulated viewport platform into PREGO's standalone
/// Material theme so production components choose the matching interaction.
final class PregoCatalogPlatformAddon({required final List<ViewportData> viewports}) extends WidgetbookAddon<bool> {
  this : super(name: "PREGO platform bridge");

  @override
  List<Field> get fields => const [];

  @override
  bool valueFromQueryGroup(Map<String, String> group) => true;

  @override
  Widget buildUseCase(BuildContext context, Widget child, bool setting) {
    final pregoTheme = material.Theme.of(context);
    final platform = resolvePregoCatalogPlatform(
      encodedViewport: WidgetbookState.of(context).queryParams["viewport"],
      viewports: viewports,
      fallback: pregoTheme.platform,
    );

    return material.Theme(
      data: pregoTheme.copyWith(platform: platform),
      child: child,
    );
  }
}

@visibleForTesting
TargetPlatform resolvePregoCatalogPlatform({
  required String? encodedViewport,
  required List<ViewportData> viewports,
  required TargetPlatform fallback,
}) {
  final viewport = ViewportAddon(viewports).valueFromQueryGroup(FieldCodec.decodeQueryGroup(encodedViewport));
  return viewport.name == Viewports.none.name ? fallback : viewport.platform;
}
