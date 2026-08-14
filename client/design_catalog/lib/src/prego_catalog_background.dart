import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

enum PregoCatalogBackground({required final String label}) {
  surface1(label: "Surface 1"),
  surface2(label: "Surface 2"),
  surface3(label: "Surface 3"),
  surface4(label: "Surface 4"),
  surface5(label: "Surface 5"),
  surface6(label: "Surface 6"),
  surface7(label: "Surface 7"),
  surface8(label: "Surface 8"),
  brandPrimary(label: "Brand primary"),
  brandPrimaryAlt(label: "Brand primary alt"),
  brandSecondary(label: "Brand secondary"),
  brandSection(label: "Brand section"),
  brandSectionSubtle(label: "Brand section subtle"),
  brandSolid(label: "Brand solid");

  Color resolve(PregoColors colors) => switch (this) {
    surface1 => colors.bgSurface1,
    surface2 => colors.bgSurface2,
    surface3 => colors.bgSurface3,
    surface4 => colors.bgSurface4,
    surface5 => colors.bgSurface5,
    surface6 => colors.bgSurface6,
    surface7 => colors.bgSurface7,
    surface8 => colors.bgSurface8,
    brandPrimary => colors.bgBrandPrimary,
    brandPrimaryAlt => colors.bgBrandPrimaryAlt,
    brandSecondary => colors.bgBrandSecondary,
    brandSection => colors.bgBrandSection,
    brandSectionSubtle => colors.bgBrandSectionSubtle,
    brandSolid => colors.bgBrandSolid,
  };
}

final class PregoCanvasBackgroundAddon() extends WidgetbookAddon<PregoCatalogBackground> {
  this : super(name: "Canvas background");

  @override
  List<Field<PregoCatalogBackground>> get fields => [
    ObjectDropdownField<PregoCatalogBackground>(
      name: "background",
      values: PregoCatalogBackground.values,
      initialValue: PregoCatalogBackground.surface1,
      labelBuilder: (background) => background.label,
    ),
  ];

  @override
  PregoCatalogBackground valueFromQueryGroup(Map<String, String> group) =>
      valueOf<PregoCatalogBackground>("background", group) ?? PregoCatalogBackground.surface1;

  @override
  Widget buildUseCase(
    BuildContext context,
    Widget child,
    PregoCatalogBackground setting,
  ) => ColoredBox(color: setting.resolve(context.prego.colors), child: child);
}
