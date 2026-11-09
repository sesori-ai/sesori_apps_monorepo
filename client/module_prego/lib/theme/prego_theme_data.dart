import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "font/prego_text_theme.dart";
import "prego_design_system.dart";
import "primitives/prego_colors_x.dart";
import "primitives/prego_radius.g.dart";

/// Builds the complete Material theme owned by the Prego design system.
ThemeData buildPregoThemeData({required Brightness brightness}) => _buildThemeData(
  brightness: brightness,
  designSystem: switch (brightness) {
    Brightness.light => PregoDesignSystem.light,
    Brightness.dark => PregoDesignSystem.dark,
  },
);

/// The theme for a shell driven by a pointer: the desktop type scale, quiet
/// icon buttons, and rows that answer with a fill instead of a touch ripple.
ThemeData buildPregoDesktopThemeData({required Brightness brightness}) {
  final designSystem = switch (brightness) {
    Brightness.light => PregoDesignSystem.desktopLight,
    Brightness.dark => PregoDesignSystem.desktopDark,
  };
  final colors = designSystem.colors;
  return _buildThemeData(brightness: brightness, designSystem: designSystem).copyWith(
    // In light, the page people read is near white and the panels step down from it.
    scaffoldBackgroundColor: brightness == Brightness.light ? colors.bgSecondary : colors.bgSurface1,
    // Takes Material's 44 pt minimum heights down to 28, so a one-line transcript
    // step or a plain button sits at the desktop's size.
    visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
    splashFactory: NoSplash.splashFactory,
    highlightColor: colors.bgSecondaryHover,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.bgSurface3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderPrimary),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 2), blurRadius: 8)],
      ),
      textStyle: designSystem.textTheme.textXs.regular.copyWith(color: colors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // Clears a composer action's 16 pt half height, its 6 pt inset and 6 pt of air.
      verticalOffset: 28,
    ),
    // macOS 27's overlay scroller, measured from NSScroller: a 6 pt knob, 3 pt from
    // the edge and the ends. It shows only while scrolling, with no track, and takes
    // no hover or drag, so it never lights up beside the sidebar's resize edge.
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      crossAxisMargin: 3,
      mainAxisMargin: 3,
      minThumbLength: 32,
      interactive: false,
      thumbVisibility: const WidgetStatePropertyAll(false),
      trackVisibility: const WidgetStatePropertyAll(false),
      thumbColor: WidgetStatePropertyAll(
        (brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.4),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: _clickableStyle.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textDisabled;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return colors.textPrimary;
          return colors.textSecondary;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)) {
            return colors.bgSecondaryHover;
          }
          return null;
        }),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PregoRadius.sm))),
        ),
      ),
    ),
  );
}

ThemeData _buildThemeData({required Brightness brightness, required PregoDesignSystem designSystem}) {
  return ThemeData(
    colorScheme: designSystem.colors.toFlutterColorScheme(),
    textTheme: designSystem.textTheme.asFlutterTextTheme(),
    fontFamily: PregoTextTheme.fontFamily,
    fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
    scaffoldBackgroundColor: designSystem.colors.bgSurface1,
    extensions: <PregoDesignSystem>[designSystem],
    appBarTheme: AppBarTheme(
      systemOverlayStyle: brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
    // Material defaults to the arrow over controls on desktop; Sesori shows the hand wherever a click acts.
    textButtonTheme: const TextButtonThemeData(style: _clickableStyle),
    iconButtonTheme: const IconButtonThemeData(style: _clickableStyle),
    filledButtonTheme: const FilledButtonThemeData(style: _clickableStyle),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: _clickableStyle),
    outlinedButtonTheme: const OutlinedButtonThemeData(style: _clickableStyle),
    segmentedButtonTheme: const SegmentedButtonThemeData(style: _clickableStyle),
    menuButtonTheme: const MenuButtonThemeData(style: _clickableStyle),
    listTileTheme: const ListTileThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    popupMenuTheme: const PopupMenuThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    checkboxTheme: const CheckboxThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    radioTheme: const RadioThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    switchTheme: const SwitchThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
  );
}

const ButtonStyle _clickableStyle = ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable);
