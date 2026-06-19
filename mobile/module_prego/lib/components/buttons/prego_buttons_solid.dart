import "package:flutter/material.dart";

import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";

// Horizontal padding for md size — not a named spacing token.
// Figma specifies 14px for md (between spacing-lg=12 and spacing-xl=16).
const double _buttonHPaddingMd = 14.0;

// Vertical padding for md size — not a named spacing token.
// Figma specifies 10px (between spacing-md=8 and spacing-lg=12).
const double _buttonVPaddingMd = 10.0;

/// Size variants for [PregoButtonsSolid].
enum PregoButtonsSolidSize {
  /// Height 36px — text-sm/medium, px=12, py=8, gap=4.
  sm,

  /// Height 40px — text-sm/bold, px=14, py=10, gap=4.
  md,

  /// Height 44px — text-md/bold, px=16, py=12, gap=6.
  lg,

  /// Height 52px — text-md/bold, px=20, py=16, gap=6.
  xl,
}

/// Hierarchy variants for [PregoButtonsSolid].
enum PregoButtonsSolidHierarchy {
  /// Filled brand-blue background with white text. Skeuomorphic border + shadow.
  primary,

  /// Filled with `fg-primary (900)` — the contrast-inverted foreground token
  /// (dark fill in light mode, light fill in dark mode) — with text and icon
  /// in `text-primary_on-white`. Shares the skeuomorphic border + shadow
  /// treatment as [primary]. Figma does not expose a destructive variant for
  /// this hierarchy.
  primaryAlt,

  /// Outlined button with secondary border and secondary text.
  secondary,

  /// Ghost button — no background, no border. Tertiary text colour.
  tertiary,

  /// Inline link style — no background, no border, no padding. Brand-secondary text colour.
  link,
}

/// Colour tone for [PregoButtonsSolid] — the colour family applied within the
/// chosen [PregoButtonsSolidHierarchy].
enum PregoButtonsSolidType {
  /// Brand blue — the default.
  regular,

  /// Error red — maps to the Figma `pregoButtonsDestructiveSolid` component.
  destructive,

  /// Warning amber. Only valid with [PregoButtonsSolidHierarchy.primary] — the
  /// only warning solid the Figma library exposes (an instance fill override on
  /// `pregoButtonsSolid`). Mirrors the destructive primary treatment with
  /// `bg-warning-solid` as the fill.
  warning,

  /// Success green. Only valid with [PregoButtonsSolidHierarchy.primary] — a
  /// `bg-success-solid` instance fill override on `pregoButtonsSolid` (used by
  /// the success `pregoInlineAlertsNotifications`). Mirrors the warning
  /// treatment: white text + neutral darken overlays + the neutral focus ring.
  success,
}

/// A solid-style button matching the Figma `pregoButtonsSolid` component.
///
/// Supports all four [PregoButtonsSolidHierarchy] values, all four
/// [PregoButtonsSolidSize] values, the [PregoButtonsSolidType] colour families,
/// icon-only mode, loading state, and disabled state.
///
/// [PregoButtonsSolidType.destructive] maps to the Figma
/// `pregoButtonsDestructiveSolid` component — identical to the brand solid button
/// except that error colour tokens replace brand colour tokens.
/// [PregoButtonsSolidType.warning] keeps that treatment with the warning fill and
/// is only valid for the [PregoButtonsSolidHierarchy.primary] hierarchy.
///
/// Hover and press overlays are handled by [PregoTappable] using alpha-blended
/// tokens (`bgPrimaryHover`, `bgPrimaryPressed`, etc.) that layer on top of
/// the base background colour. This matches the Figma approach of compositing
/// semi-transparent overlays (e.g. `rgba(0,0,0,0.16)` for hover) over the
/// base fill.
///
/// Usage:
/// ```dart
/// PregoButtonsSolid(
///   label: 'Submit',
///   hierarchy: PregoButtonsSolidHierarchy.primary,
///   size: PregoButtonsSolidSize.md,
///   onPressed: () {},
/// )
///
/// PregoButtonsSolid(
///   label: 'Delete',
///   hierarchy: PregoButtonsSolidHierarchy.primary,
///   size: PregoButtonsSolidSize.md,
///   type: PregoButtonsSolidType.destructive,
///   onPressed: () {},
/// )
/// ```
class PregoButtonsSolid extends StatefulWidget {
  const PregoButtonsSolid({
    super.key,
    required this.label,
    required this.hierarchy,
    required this.size,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.type = PregoButtonsSolidType.regular,
    this.fullWidth = false,
  }) : assert(
         hierarchy != PregoButtonsSolidHierarchy.primaryAlt || type == PregoButtonsSolidType.regular,
         'primaryAlt only supports the brand tone — Figma defines no destructive/warning variant for it.',
       ),
       assert(
         type != PregoButtonsSolidType.warning || hierarchy == PregoButtonsSolidHierarchy.primary,
         'The warning tone is only defined for the primary hierarchy.',
       ),
       assert(
         type != PregoButtonsSolidType.success || hierarchy == PregoButtonsSolidHierarchy.primary,
         'The success tone is only defined for the primary hierarchy.',
       ),
       iconOnly = false;

  /// Icon-only variant — renders a square button with a single centred icon.
  const PregoButtonsSolid.iconOnly({
    super.key,
    required this.leadingIcon,
    required this.hierarchy,
    required this.size,
    required this.onPressed,
    this.isLoading = false,
    this.type = PregoButtonsSolidType.regular,
  }) : assert(
         hierarchy != PregoButtonsSolidHierarchy.primaryAlt || type == PregoButtonsSolidType.regular,
         'primaryAlt only supports the brand tone — Figma defines no destructive/warning variant for it.',
       ),
       assert(
         type != PregoButtonsSolidType.warning || hierarchy == PregoButtonsSolidHierarchy.primary,
         'The warning tone is only defined for the primary hierarchy.',
       ),
       assert(
         type != PregoButtonsSolidType.success || hierarchy == PregoButtonsSolidHierarchy.primary,
         'The success tone is only defined for the primary hierarchy.',
       ),
       iconOnly = true,
       fullWidth = false,
       label = null,
       trailingIcon = null;

  /// Button label text. Required for the standard constructor; null for icon-only.
  final String? label;

  /// Hierarchy determines background, border, and text colour.
  final PregoButtonsSolidHierarchy hierarchy;

  /// Governs height, padding, gap, and typography scale.
  final PregoButtonsSolidSize size;

  /// Called when the button is tapped. Pass `null` to render in disabled state.
  /// When [isLoading] is `true`, the button is always disabled regardless of this value.
  final VoidCallback? onPressed;

  /// Optional icon placed before the label.
  final IconData? leadingIcon;

  /// Optional icon placed after the label. Ignored when [iconOnly] is `true`.
  final IconData? trailingIcon;

  /// When `true` the button shows a spinner and the button label instead of
  /// its normal content. The button is always non-interactive while loading,
  /// even if [onPressed] is non-null.
  final bool isLoading;

  /// Colour family for the button. Defaults to [PregoButtonsSolidType.regular].
  ///
  /// [PregoButtonsSolidType.destructive] swaps brand tokens for error tokens (the
  /// Figma `pregoButtonsDestructiveSolid` component); [PregoButtonsSolidType.warning]
  /// keeps that treatment with the warning fill and is only valid with the
  /// [PregoButtonsSolidHierarchy.primary] hierarchy.
  final PregoButtonsSolidType type;

  /// Whether the button renders in icon-only mode (square, no label).
  final bool iconOnly;

  /// When `true`, the button expands to fill its parent's width and centres
  /// the icon + label horizontally. Requires the parent to provide bounded
  /// width constraints (e.g. via [SizedBox], [Expanded], or a [Column] with
  /// `crossAxisAlignment: CrossAxisAlignment.stretch`). Ignored when
  /// [iconOnly] is `true`.
  final bool fullWidth;

  @override
  State<PregoButtonsSolid> createState() => _PregoButtonsSolidState();
}

class _PregoButtonsSolidState extends State<PregoButtonsSolid> {
  bool _isFocused = false;

  bool get _isDestructive => widget.type == PregoButtonsSolidType.destructive;
  bool get _isWarning => widget.type == PregoButtonsSolidType.warning;
  bool get _isSuccess => widget.type == PregoButtonsSolidType.success;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final button = Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: PregoTappable.stateAware(
        onTap: widget.isLoading ? null : widget.onPressed,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return _resolvePressOverlayColor(colors: colors);
          if (states.contains(WidgetState.hovered)) return _resolveHoverOverlayColor(colors: colors);
          return null;
        }),
        overlayInset: _resolveOverlayInset(),
        containerBuilder: ({required Widget child, required Set<WidgetState> state}) {
          final isHovered = state.contains(WidgetState.hovered);
          final isPressed = state.contains(WidgetState.pressed);
          // Resolve background colour based on hierarchy, state, and mode.
          final bgColor = _resolveBgColor(colors: colors, state: state);

          // Resolve border.
          final border = _resolveBorder(colors: colors, state: state);

          // Resolve focus ring / drop shadows.
          final boxShadows = _resolveBoxShadows(colors: colors, state: state);

          final decoration = BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(PregoRadius.full),
            border: border,
            boxShadow: boxShadows,
          );

          // Primary and secondary (regular): skeuomorphic overlay shown at rest, hover, and loading.
          // Primary: hidden when focused or disabled.
          // Secondary (regular): always shown, but in the focused state both the ring
          //   and the bottom strip use skeuomorphicInnerBorder (instead of skeuomorphicShadow).
          // Secondary (destructive): shown at rest and loading only (not on hover/pressed).
          // Tertiary and link: never shown.
          final isDisabled = state.contains(WidgetState.disabled);
          final showSkeuomorphicOverlay = switch (widget.hierarchy) {
            PregoButtonsSolidHierarchy.primary ||
            PregoButtonsSolidHierarchy.primaryAlt => !_isFocused && (!isDisabled || widget.isLoading),
            PregoButtonsSolidHierarchy.secondary => _isDestructive ? ((!isHovered && !isPressed) || isDisabled) : true,
            PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => false,
          };
          final skeuomorphicBottomColor = _isFocused && widget.hierarchy == PregoButtonsSolidHierarchy.secondary
              ? colors.skeuomorphicInnerBorder
              : colors.skeuomorphicShadow;

          return DecoratedBox(
            decoration: decoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PregoRadius.full),
              child: Stack(
                children: [
                  child,
                  if (showSkeuomorphicOverlay)
                    _SkeuomorphicInnerOverlay(
                      innerBorderColor: colors.skeuomorphicInnerBorder,
                      bottomShadowColor: skeuomorphicBottomColor,
                    ),
                ],
              ),
            ),
          );
        },
        childBuilder: ({required Set<WidgetState> state}) {
          return widget.iconOnly
              ? _buildIconOnlyContent(prego: prego, state: state)
              : _buildLabelContent(prego: prego, state: state);
        },
      ),
    );

    // Secondary, tertiary, and link use 0.8 opacity for the disabled state rather
    // than the dedicated disabled-colour tokens used by primary / primaryAlt.
    final isNonPrimaryDisabled =
        widget.onPressed == null &&
        !widget.isLoading &&
        widget.hierarchy != PregoButtonsSolidHierarchy.primary &&
        widget.hierarchy != PregoButtonsSolidHierarchy.primaryAlt;

    return isNonPrimaryDisabled ? Opacity(opacity: 0.8, child: button) : button;
  }

  // ---------------------------------------------------------------------------
  // Content builders
  // ---------------------------------------------------------------------------

  Widget _buildLabelContent({required PregoDesignSystem prego, required Set<WidgetState> state}) {
    final colors = prego.colors;
    final textStyle = _resolveTextStyle(prego: prego, state: state);
    final iconColor = _resolveIconColor(colors: colors, state: state);
    final padding = _resolvePadding();
    final gap = _resolveGap();

    final List<Widget> children = [];

    final labelWidget = Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xxs),
      child: Text(widget.label ?? '', style: textStyle),
    );

    if (widget.isLoading) {
      children.add(_LoadingSpinner(color: textStyle.color ?? colors.textWhite, size: _resolveIconSize()));
      children.add(SizedBox(width: gap));
      children.add(labelWidget);
    } else {
      if (widget.leadingIcon != null) {
        children.add(Icon(widget.leadingIcon, size: _resolveIconSize(), color: iconColor));
        children.add(SizedBox(width: gap));
      }
      children.add(labelWidget);
      if (widget.trailingIcon != null) {
        children.add(SizedBox(width: gap));
        children.add(Icon(widget.trailingIcon, size: _resolveIconSize(), color: iconColor));
      }
    }

    return Padding(
      padding: padding,
      child: Row(
        // [fullWidth] stretches the Row to fill the parent so the centered
        // alignment below actually has spare space to centre into. The default
        // min-size collapses the Row to its content (existing behaviour).
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildIconOnlyContent({required PregoDesignSystem prego, required Set<WidgetState> state}) {
    final colors = prego.colors;
    final iconColor = _resolveIconColor(colors: colors, state: state);
    final padding = _resolveIconOnlyPadding();

    final Widget iconWidget;
    if (widget.isLoading) {
      iconWidget = _LoadingSpinner(color: iconColor, size: _resolveIconSize());
    } else {
      iconWidget = Icon(widget.leadingIcon, size: _resolveIconSize(), color: iconColor);
    }

    return Padding(
      padding: padding,
      child: iconWidget,
    );
  }

  // ---------------------------------------------------------------------------
  // Overlay colour resolution
  // ---------------------------------------------------------------------------

  /// Returns the overlay colour applied on hover by [PregoTappable].
  ///
  /// Regular primary/secondary: `bgPrimaryHover` (semi-transparent black overlay on base bg).
  /// Destructive primary: `bgPrimaryHoverDestructive` (same visual as regular hover overlay).
  /// Destructive secondary/tertiary: transparent — hover is handled via bg colour change
  /// in [containerBuilder] because Figma uses opaque fills (e.g. `bgHoverDestructiveAlt`)
  /// instead of overlays.
  /// Tertiary regular: transparent — hover bg is set directly to `bgPrimaryHover`.
  /// Link: transparent — no hover background.
  Color _resolveHoverOverlayColor({required PregoColors colors}) {
    return switch (widget.hierarchy) {
      // Warning and success reuse the destructive darken overlay (gray-alpha, tone-neutral).
      PregoButtonsSolidHierarchy.primary =>
        (_isDestructive || _isWarning || _isSuccess) ? colors.bgDestructiveHover : colors.bgBrandHover,
      // Primary Alt uses a translucent alpha overlay (alpha-white-10) that darkens
      // in light mode and lightens in dark mode — Figma does not define dedicated
      // hover/press background tokens for this hierarchy.
      PregoButtonsSolidHierarchy.primaryAlt => colors.alphaWhite10,
      PregoButtonsSolidHierarchy.secondary => _isDestructive ? Colors.transparent : colors.bgGrayHover,
      PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => Colors.transparent,
    };
  }

  /// Returns the overlay colour applied on press by [PregoTappable].
  ///
  /// Regular primary/secondary: semi-transparent overlay on base bg.
  /// Destructive primary: `bgDestructivePressed`.
  /// Destructive secondary/tertiary: transparent — press bg handled via container.
  /// Tertiary regular: transparent — bg handles pressed state directly.
  /// Link: transparent — no press background.
  Color _resolvePressOverlayColor({required PregoColors colors}) {
    return switch (widget.hierarchy) {
      PregoButtonsSolidHierarchy.primary =>
        (_isDestructive || _isWarning || _isSuccess) ? colors.bgDestructivePressed : colors.bgBrandPressed,
      // Stronger alpha overlay on press for Primary Alt (alpha-white-20).
      PregoButtonsSolidHierarchy.primaryAlt => colors.alphaWhite20,
      PregoButtonsSolidHierarchy.secondary => _isDestructive ? Colors.transparent : colors.bgGrayPressed,
      // Tertiary: bg handles pressed state directly (no overlay needed).
      PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => Colors.transparent,
    };
  }

  /// Returns the inset distance for the hover/press overlay so it does not
  /// paint over the component's border.
  ///
  /// Primary (enabled) has a 2px border, so the overlay is inset by 2.
  /// Secondary (enabled) has a 1px border, so the overlay is inset by 1.
  /// Disabled primary has a 1px border, but overlays are disabled anyway.
  double _resolveOverlayInset() {
    if (widget.onPressed == null || widget.isLoading) return 0.0;
    return switch (widget.hierarchy) {
      // Both Primary and Primary Alt have a 2px translucent border at rest.
      PregoButtonsSolidHierarchy.primary || PregoButtonsSolidHierarchy.primaryAlt => 2.0,
      PregoButtonsSolidHierarchy.secondary => 1.0,
      PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => 0.0,
    };
  }

  // ---------------------------------------------------------------------------
  // Token resolution helpers
  // ---------------------------------------------------------------------------

  Color _resolveBgColor({required PregoColors colors, required Set<WidgetState> state}) {
    final isEnabled = !state.contains(WidgetState.disabled) || widget.isLoading;
    final isHovered = state.contains(WidgetState.hovered);
    final isPressed = state.contains(WidgetState.pressed);

    return switch (widget.hierarchy) {
      PregoButtonsSolidHierarchy.primary => _primaryBgColor(
        colors: colors,
        isEnabled: isEnabled,
      ),
      PregoButtonsSolidHierarchy.primaryAlt => _primaryAltBgColor(
        colors: colors,
        isEnabled: isEnabled,
      ),
      PregoButtonsSolidHierarchy.secondary => _secondaryBgColor(
        colors: colors,
        isEnabled: isEnabled,
        isHovered: isHovered,
        isPressed: isPressed,
      ),
      PregoButtonsSolidHierarchy.tertiary => _tertiaryBgColor(
        colors: colors,
        isEnabled: isEnabled,
        isHovered: isHovered,
        isPressed: isPressed,
      ),
      // Link uses the same press bg as tertiary for consistent tap feedback.
      PregoButtonsSolidHierarchy.link => _linkBgColor(
        colors: colors,
        isEnabled: isEnabled,
        isPressed: isPressed,
      ),
    };
  }

  Color _primaryBgColor({required PregoColors colors, required bool isEnabled}) {
    // Disabled: bg-disabled (shared across all tones).
    if (!isEnabled) return colors.bgDisabled;
    // Enabled, hover, and loading all use the same base bg.
    // Hover/press darkening is handled by the PregoTappable overlay.
    return switch (widget.type) {
      PregoButtonsSolidType.regular => colors.bgBrandSolid,
      PregoButtonsSolidType.destructive => colors.bgErrorSolid,
      PregoButtonsSolidType.warning => colors.bgWarningSolid,
      PregoButtonsSolidType.success => colors.bgSuccessSolid,
    };
  }

  Color _primaryAltBgColor({required PregoColors colors, required bool isEnabled}) {
    // Disabled: bg-disabled (matches primary's disabled treatment).
    if (!isEnabled) return colors.bgDisabled;
    // Enabled / hover / pressed / loading all share the same base bg.
    // Figma uses `Colors/Foreground/fg-primary (900)` as the background fill
    // for this hierarchy — the contrast-inverted foreground token, not a
    // brand-tinted bg. Hover/press tinting is handled by the alphaWhite10/20
    // overlays in PregoTappable rather than a bg colour swap.
    return colors.fgPrimary;
  }

  Color _secondaryBgColor({
    required PregoColors colors,
    required bool isEnabled,
    required bool isHovered,
    required bool isPressed,
  }) {
    if (!isEnabled) {
      // Disabled secondary uses bg-disabled for both regular and destructive.
      return colors.bgDisabled;
    }

    if (_isDestructive) {
      // Destructive secondary: pressed and hover use opaque bg colours directly
      // (no overlay). isPressed takes priority over isHovered.
      if (isPressed) return colors.bgDestructivePressedAlt;
      if (isHovered) return colors.bgDestructiveHoverAlt;
      // Default and loading: bg-primary (white).
      return colors.bgPrimary;
    }

    // Regular secondary: bg-primary_alt at rest. Hover darkening is handled by
    // the PregoTappable overlay (bgPrimaryHover = rgba(0,0,0,0.16) composited
    // on top of bg-primary_alt).
    if (_isFocused) return colors.bgPrimary;
    return colors.bgPrimaryAlt;
  }

  Color _tertiaryBgColor({
    required PregoColors colors,
    required bool isEnabled,
    required bool isHovered,
    required bool isPressed,
  }) {
    // Focused tertiary uses bg-primary (white) as a base.
    if (_isFocused) return colors.bgPrimary;

    if (_isDestructive) {
      // Destructive tertiary: pressed and hover use opaque bg colours directly
      // (no overlay). isPressed takes priority over isHovered.
      if (isPressed) return colors.bgDestructivePressedAlt;
      if (isHovered) return colors.bgDestructiveHoverAlt;
      return Colors.transparent;
    }

    // Regular tertiary: pressed and hover use grey bg fills directly.
    // isPressed takes priority over isHovered to avoid double-darkening
    // (bg + overlay stacking). No press overlay is used for tertiary.
    if (isPressed) return colors.bgGrayPressed;
    if (widget.isLoading || isHovered) return colors.bgGrayHover;
    return Colors.transparent;
  }

  Color _linkBgColor({
    required PregoColors colors,
    required bool isEnabled,
    required bool isPressed,
  }) {
    // Link has no bg at rest or on hover. On press, use the same bg as tertiary
    // for consistent tap feedback across platforms (especially Android).
    if (!isPressed || !isEnabled) return Colors.transparent;
    return _isDestructive ? colors.bgDestructivePressedAlt : colors.bgGrayPressed;
  }

  Border? _resolveBorder({required PregoColors colors, required Set<WidgetState> state}) {
    final isDisabled = state.contains(WidgetState.disabled);
    final isPressed = state.contains(WidgetState.pressed);
    if (isDisabled && !widget.isLoading) {
      return switch (widget.hierarchy) {
        PregoButtonsSolidHierarchy.primary =>
          _isDestructive
              // Destructive primary disabled: fg-disabled_subtle border.
              ? Border.all(color: colors.fgDisabledSubtle, width: 1)
              // Regular primary disabled: border-disabled.
              : Border.all(color: colors.borderDisabled, width: 1),
        // Primary Alt disabled: border-disabled (matches primary regular disabled).
        // No destructive variant exists for primaryAlt.
        PregoButtonsSolidHierarchy.primaryAlt => Border.all(color: colors.borderDisabled, width: 1),
        PregoButtonsSolidHierarchy.secondary =>
          _isDestructive
              // Destructive secondary disabled: border-disabled_subtle.
              ? Border.all(color: colors.borderDisabledSubtle, width: 1)
              // Regular secondary disabled: border-disabled_subtle.
              : Border.all(color: colors.borderDisabledSubtle, width: 1),
        PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => null,
      };
    }

    return switch (widget.hierarchy) {
      // Primary: 2px semi-transparent white border (rgba(255,255,255,0.12) = alpha-white-10).
      PregoButtonsSolidHierarchy.primary => Border.all(color: colors.alphaWhite10, width: 2),
      // Primary Alt: 2px alpha-white-10 at rest/hover; the pressed Figma variant
      // swaps the stroke to a solid border-primary stroke for stronger feedback.
      PregoButtonsSolidHierarchy.primaryAlt => Border.all(
        color: isPressed ? colors.borderPrimary : colors.alphaWhite10,
        width: 2,
      ),
      PregoButtonsSolidHierarchy.secondary =>
        _isDestructive
            // Destructive secondary: border-error_subtle for all active states.
            ? Border.all(color: colors.borderErrorSubtle, width: 1)
            // Regular secondary: border-primary on hover/focused; border-secondary at rest.
            : Border.all(
                color: (state.contains(WidgetState.hovered) || _isFocused)
                    ? colors.borderPrimary
                    : colors.borderSecondary,
                width: 1,
              ),
      PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => null,
    };
  }

  List<BoxShadow>? _resolveBoxShadows({required PregoColors colors, required Set<WidgetState> state}) {
    // Warning has no dedicated focus-ring token, so it uses the neutral brand
    // ring (the ring conveys keyboard focus, not semantic colour).
    final focusRingColor = _isDestructive ? colors.focusRingError : colors.focusRing;

    // Tertiary and link: 2-layer focus ring only when focused; no drop shadow ever.
    if (widget.hierarchy == PregoButtonsSolidHierarchy.tertiary ||
        widget.hierarchy == PregoButtonsSolidHierarchy.link) {
      if (!_isFocused) return null;
      return [
        BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 4),
        BoxShadow(color: colors.bgPrimary, blurRadius: 0, spreadRadius: 2),
      ];
    }

    // Primary and secondary: focus ring + xs drop shadow when focused.
    if (_isFocused) {
      return [
        BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 4),
        BoxShadow(color: colors.bgPrimary, blurRadius: 0, spreadRadius: 2),
        BoxShadow(color: colors.shadowXs, offset: const Offset(0, 1), blurRadius: 2),
      ];
    }

    // Drop shadow: shadow-xs for default/disabled/secondary-hover.
    // Primary and Primary Alt hover use shadow-skeumorphic (a semantically distinct
    // token that happens to be visually near-identical today, but may diverge later).
    final isPrimaryFamily =
        widget.hierarchy == PregoButtonsSolidHierarchy.primary ||
        widget.hierarchy == PregoButtonsSolidHierarchy.primaryAlt;
    final shadowColor = state.contains(WidgetState.hovered) && isPrimaryFamily
        ? colors.skeuomorphicShadow
        : colors.shadowXs;
    return [BoxShadow(color: shadowColor, offset: const Offset(0, 1), blurRadius: 2)];
  }

  TextStyle _resolveTextStyle({required PregoDesignSystem prego, required Set<WidgetState> state}) {
    final colors = prego.colors;
    final textColor = _resolveTextColor(colors: colors, state: state);
    // sm: Medium weight (w500) per Figma. md/lg/xl: Bold (w700).
    final baseStyle = switch (widget.size) {
      PregoButtonsSolidSize.sm => prego.textTheme.textSm.medium,
      PregoButtonsSolidSize.md => prego.textTheme.textSm.bold,
      PregoButtonsSolidSize.lg || PregoButtonsSolidSize.xl => prego.textTheme.textMd.bold,
    };
    // Link shows an underline on hover.
    final decoration = widget.hierarchy == PregoButtonsSolidHierarchy.link && state.contains(WidgetState.hovered)
        ? TextDecoration.underline
        : null;
    return baseStyle.copyWith(color: textColor, decoration: decoration);
  }

  Color _resolveTextColor({required PregoColors colors, required Set<WidgetState> state}) {
    final isDisabled = state.contains(WidgetState.disabled);
    final isHovered = state.contains(WidgetState.hovered);
    if (isDisabled && !widget.isLoading) {
      return switch (widget.hierarchy) {
        // Primary disabled: fg-disabled for both regular and destructive.
        PregoButtonsSolidHierarchy.primary => colors.fgDisabled,
        // Primary Alt disabled: fg-disabled (matches primary's disabled treatment).
        PregoButtonsSolidHierarchy.primaryAlt => colors.fgDisabled,
        // Secondary disabled: text-disabled (regular), text-disabled (destructive).
        PregoButtonsSolidHierarchy.secondary => colors.textDisabled,
        // Tertiary disabled: fg-disabled.
        PregoButtonsSolidHierarchy.tertiary => colors.fgDisabled,
        // Link disabled: fg-disabled.
        PregoButtonsSolidHierarchy.link => colors.fgDisabled,
      };
    }

    if (_isDestructive) {
      return switch (widget.hierarchy) {
        // Destructive primary: always text-white.
        PregoButtonsSolidHierarchy.primary => colors.textWhite,
        // Unreachable — assertion in constructor blocks primaryAlt + destructive.
        PregoButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
        // Destructive secondary: text-error-primary at rest, text-error-primary_hover on hover.
        PregoButtonsSolidHierarchy.secondary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        // Destructive tertiary: text-error-primary at rest, text-error-primary_hover on hover.
        PregoButtonsSolidHierarchy.tertiary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        // Destructive link: text-error-primary at rest, text-error-primary_hover on hover.
        PregoButtonsSolidHierarchy.link => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
      };
    }

    return switch (widget.hierarchy) {
      PregoButtonsSolidHierarchy.primary => colors.textWhite,
      // Primary Alt: text-primary_on-white (dark on a brand-tinted/light bg).
      // No hover change — overlay handles the hover/press feedback.
      PregoButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
      // Secondary text colour does not change on hover (only background does).
      PregoButtonsSolidHierarchy.secondary => colors.textSecondary,
      PregoButtonsSolidHierarchy.tertiary => colors.textTertiary,
      PregoButtonsSolidHierarchy.link => isHovered ? colors.textBrandSecondaryHover : colors.textBrandSecondary,
    };
  }

  Color _resolveIconColor({required PregoColors colors, required Set<WidgetState> state}) {
    final isDisabled = state.contains(WidgetState.disabled);
    final isHovered = state.contains(WidgetState.hovered);
    if (isDisabled && !widget.isLoading) {
      // Disabled icon colour: fg-disabled for primary, text-disabled for secondary,
      // fg-disabled for tertiary/link.
      return switch (widget.hierarchy) {
        PregoButtonsSolidHierarchy.primary => colors.fgDisabled,
        PregoButtonsSolidHierarchy.primaryAlt => colors.fgDisabled,
        PregoButtonsSolidHierarchy.secondary => colors.textDisabled,
        PregoButtonsSolidHierarchy.tertiary || PregoButtonsSolidHierarchy.link => colors.fgDisabled,
      };
    }

    if (_isDestructive) {
      return switch (widget.hierarchy) {
        PregoButtonsSolidHierarchy.primary => colors.textWhite,
        // Unreachable — assertion in constructor blocks primaryAlt + destructive.
        PregoButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
        PregoButtonsSolidHierarchy.secondary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        PregoButtonsSolidHierarchy.tertiary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        PregoButtonsSolidHierarchy.link => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
      };
    }

    return switch (widget.hierarchy) {
      // Primary (regular) always uses text-white for the icon.
      PregoButtonsSolidHierarchy.primary => colors.textWhite,
      // Primary Alt: icon matches the dark text colour (text-primary_on-white).
      PregoButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
      // Secondary and tertiary icon color is static across all active states (no hover change).
      PregoButtonsSolidHierarchy.secondary => colors.textSecondary,
      PregoButtonsSolidHierarchy.tertiary => colors.textTertiary,
      // Link uses text-brand-secondary tokens on default/hover; text-secondary when focused.
      PregoButtonsSolidHierarchy.link =>
        _isFocused ? colors.textSecondary : (isHovered ? colors.textBrandSecondaryHover : colors.textBrandSecondary),
    };
  }

  EdgeInsetsDirectional _resolvePadding() => switch (widget.size) {
    // sm: 12px horizontal (spacing-lg) per Figma — differs from md's 14px.
    PregoButtonsSolidSize.sm => const EdgeInsetsDirectional.symmetric(
      horizontal: PregoSpacing.lg,
      vertical: PregoSpacing.md,
    ),
    PregoButtonsSolidSize.md => const EdgeInsetsDirectional.symmetric(
      horizontal: _buttonHPaddingMd,
      vertical: _buttonVPaddingMd,
    ),
    PregoButtonsSolidSize.lg => const EdgeInsetsDirectional.symmetric(
      horizontal: PregoSpacing.xl,
      vertical: PregoSpacing.lg,
    ),
    PregoButtonsSolidSize.xl => const EdgeInsetsDirectional.symmetric(
      horizontal: PregoSpacing.x2l,
      vertical: PregoSpacing.xl,
    ),
  };

  EdgeInsetsDirectional _resolveIconOnlyPadding() => switch (widget.size) {
    PregoButtonsSolidSize.sm => const EdgeInsetsDirectional.all(PregoSpacing.md),
    PregoButtonsSolidSize.md => const EdgeInsetsDirectional.all(_buttonVPaddingMd),
    PregoButtonsSolidSize.lg => const EdgeInsetsDirectional.all(PregoSpacing.lg),
    PregoButtonsSolidSize.xl => const EdgeInsetsDirectional.all(PregoSpacing.xl),
  };

  double _resolveGap() => switch (widget.size) {
    PregoButtonsSolidSize.sm || PregoButtonsSolidSize.md => PregoSpacing.xs,
    PregoButtonsSolidSize.lg || PregoButtonsSolidSize.xl => PregoSpacing.sm,
  };

  double _resolveIconSize() => 20.0;
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

/// Paints the skeuomorphic inner border used on Primary and Secondary hierarchy.
///
/// Uses [CustomPainter] to approximate the two Figma inner shadow layers:
/// - A 1px inset stroke around the entire pill (inner border highlight).
/// - A 2px inset stroke along the bottom edge only (depth shadow).
///
/// In the Secondary focused state, [bottomShadowColor] is set to
/// [skeuomorphicInnerBorder] so both layers use the same token.
class _SkeuomorphicInnerOverlay extends StatelessWidget {
  const _SkeuomorphicInnerOverlay({
    required this.innerBorderColor,
    required this.bottomShadowColor,
  });

  final Color innerBorderColor;
  final Color bottomShadowColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SkeuomorphicPainter(
            innerBorderColor: innerBorderColor,
            bottomShadowColor: bottomShadowColor,
          ),
        ),
      ),
    );
  }
}

class _SkeuomorphicPainter extends CustomPainter {
  _SkeuomorphicPainter({
    required this.innerBorderColor,
    required this.bottomShadowColor,
  });

  final Color innerBorderColor;
  final Color bottomShadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Use a high enough radius to handle the pill shape.
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 1px inner border around the entire button.
    final borderPaint = Paint()
      ..color = innerBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect.deflate(0.5), borderPaint);

    // 2px-tall bottom inner shadow strip drawn by clipping and painting a rect.
    // Approximates Figma's `inset 0 -2px 0 0` inner shadow.
    canvas.save();
    canvas.clipRRect(rrect);
    final bottomShadowPaint = Paint()..color = bottomShadowColor;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 2),
      bottomShadowPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkeuomorphicPainter oldDelegate) =>
      innerBorderColor != oldDelegate.innerBorderColor || bottomShadowColor != oldDelegate.bottomShadowColor;
}

/// A small circular progress indicator used in the button loading state.
class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator.adaptive(
      constraints: BoxConstraints.tight(Size(size, size)),
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(color),
    );
  }
}
