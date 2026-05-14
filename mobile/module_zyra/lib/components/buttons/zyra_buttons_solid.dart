import "package:flutter/material.dart";

import "../../interactions/zyra_tappable.dart";
import "../../theme/zyra_theme.dart";

// Horizontal padding for md size — not a named spacing token.
// Figma specifies 14px for md (between spacing-lg=12 and spacing-xl=16).
const double _buttonHPaddingMd = 14.0;

// Vertical padding for md size — not a named spacing token.
// Figma specifies 10px (between spacing-md=8 and spacing-lg=12).
const double _buttonVPaddingMd = 10.0;

/// Size variants for [ZyraButtonsSolid].
enum ZyraButtonsSolidSize {
  /// Height 36px — text-sm/medium, px=12, py=8, gap=4.
  sm,

  /// Height 40px — text-sm/bold, px=14, py=10, gap=4.
  md,

  /// Height 44px — text-md/bold, px=16, py=12, gap=6.
  lg,

  /// Height 52px — text-md/bold, px=20, py=16, gap=6.
  xl,
}

/// Hierarchy variants for [ZyraButtonsSolid].
enum ZyraButtonsSolidHierarchy {
  /// Filled brand-blue background with white text. Skeuomorphic border + shadow.
  primary,

  /// Filled brand-tinted background (brand-50 in light, bg-secondary in dark) with
  /// dark text. Shares the skeuomorphic border + shadow treatment as [primary].
  /// Figma does not expose a destructive variant for this hierarchy.
  primaryAlt,

  /// Outlined button with secondary border and secondary text.
  secondary,

  /// Ghost button — no background, no border. Tertiary text colour.
  tertiary,

  /// Inline link style — no background, no border, no padding. Brand-secondary text colour.
  link,
}

/// A solid-style button matching the Figma `zyraButtonsSolid` component.
///
/// Supports all four [ZyraButtonsSolidHierarchy] values, all four
/// [ZyraButtonsSolidSize] values, a `destructive` flag, icon-only mode,
/// loading state, and disabled state.
///
/// The `destructive` flag maps to the Figma `zyraButtonsDestructiveSolid`
/// component — it is identical to the regular solid button except that
/// error colour tokens replace brand colour tokens.
///
/// Hover and press overlays are handled by [ZyraTappable] using alpha-blended
/// tokens (`bgPrimaryHover`, `bgPrimaryPressed`, etc.) that layer on top of
/// the base background colour. This matches the Figma approach of compositing
/// semi-transparent overlays (e.g. `rgba(0,0,0,0.16)` for hover) over the
/// base fill.
///
/// Usage:
/// ```dart
/// ZyraButtonsSolid(
///   label: 'Submit',
///   hierarchy: ZyraButtonsSolidHierarchy.primary,
///   size: ZyraButtonsSolidSize.md,
///   onPressed: () {},
/// )
///
/// ZyraButtonsSolid(
///   label: 'Delete',
///   hierarchy: ZyraButtonsSolidHierarchy.primary,
///   size: ZyraButtonsSolidSize.md,
///   destructive: true,
///   onPressed: () {},
/// )
/// ```
class ZyraButtonsSolid extends StatefulWidget {
  const ZyraButtonsSolid({
    super.key,
    required this.label,
    required this.hierarchy,
    required this.size,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.destructive = false,
    this.fullWidth = false,
  }) : assert(
         hierarchy != ZyraButtonsSolidHierarchy.primaryAlt || !destructive,
         'destructive=true is not supported for primaryAlt — Figma does not define this variant.',
       ),
       iconOnly = false;

  /// Icon-only variant — renders a square button with a single centred icon.
  const ZyraButtonsSolid.iconOnly({
    super.key,
    required this.leadingIcon,
    required this.hierarchy,
    required this.size,
    required this.onPressed,
    this.isLoading = false,
    this.destructive = false,
  }) : assert(
         hierarchy != ZyraButtonsSolidHierarchy.primaryAlt || !destructive,
         'destructive=true is not supported for primaryAlt — Figma does not define this variant.',
       ),
       iconOnly = true,
       fullWidth = false,
       label = null,
       trailingIcon = null;

  /// Button label text. Required for the standard constructor; null for icon-only.
  final String? label;

  /// Hierarchy determines background, border, and text colour.
  final ZyraButtonsSolidHierarchy hierarchy;

  /// Governs height, padding, gap, and typography scale.
  final ZyraButtonsSolidSize size;

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

  /// When `true`, error colour tokens are used instead of brand colour tokens,
  /// matching the Figma `zyraButtonsDestructiveSolid` component.
  final bool destructive;

  /// Whether the button renders in icon-only mode (square, no label).
  final bool iconOnly;

  /// When `true`, the button expands to fill its parent's width and centres
  /// the icon + label horizontally. Requires the parent to provide bounded
  /// width constraints (e.g. via [SizedBox], [Expanded], or a [Column] with
  /// `crossAxisAlignment: CrossAxisAlignment.stretch`). Ignored when
  /// [iconOnly] is `true`.
  final bool fullWidth;

  @override
  State<ZyraButtonsSolid> createState() => _ZyraButtonsSolidState();
}

class _ZyraButtonsSolidState extends State<ZyraButtonsSolid> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final button = Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: ZyraTappable.stateAware(
        onTap: widget.isLoading ? null : widget.onPressed,
        borderRadius: BorderRadius.circular(ZyraRadius.full),
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
            borderRadius: BorderRadius.circular(ZyraRadius.full),
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
            ZyraButtonsSolidHierarchy.primary ||
            ZyraButtonsSolidHierarchy.primaryAlt => !_isFocused && (!isDisabled || widget.isLoading),
            ZyraButtonsSolidHierarchy.secondary =>
              widget.destructive ? ((!isHovered && !isPressed) || isDisabled) : true,
            ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => false,
          };
          final skeuomorphicBottomColor = _isFocused && widget.hierarchy == ZyraButtonsSolidHierarchy.secondary
              ? colors.skeuomorphicInnerBorder
              : colors.skeuomorphicShadow;

          return DecoratedBox(
            decoration: decoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ZyraRadius.full),
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
              ? _buildIconOnlyContent(zyra: zyra, state: state)
              : _buildLabelContent(zyra: zyra, state: state);
        },
      ),
    );

    // Secondary, tertiary, and link use 0.8 opacity for the disabled state rather
    // than the dedicated disabled-colour tokens used by primary / primaryAlt.
    final isNonPrimaryDisabled =
        widget.onPressed == null &&
        !widget.isLoading &&
        widget.hierarchy != ZyraButtonsSolidHierarchy.primary &&
        widget.hierarchy != ZyraButtonsSolidHierarchy.primaryAlt;

    return isNonPrimaryDisabled ? Opacity(opacity: 0.8, child: button) : button;
  }

  // ---------------------------------------------------------------------------
  // Content builders
  // ---------------------------------------------------------------------------

  Widget _buildLabelContent({required ZyraDesignSystem zyra, required Set<WidgetState> state}) {
    final colors = zyra.colors;
    final textStyle = _resolveTextStyle(zyra: zyra, state: state);
    final iconColor = _resolveIconColor(colors: colors, state: state);
    final padding = _resolvePadding();
    final gap = _resolveGap();

    final List<Widget> children = [];

    final labelWidget = Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: ZyraSpacing.xxs),
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

  Widget _buildIconOnlyContent({required ZyraDesignSystem zyra, required Set<WidgetState> state}) {
    final colors = zyra.colors;
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

  /// Returns the overlay colour applied on hover by [ZyraTappable].
  ///
  /// Regular primary/secondary: `bgPrimaryHover` (semi-transparent black overlay on base bg).
  /// Destructive primary: `bgPrimaryHoverDestructive` (same visual as regular hover overlay).
  /// Destructive secondary/tertiary: transparent — hover is handled via bg colour change
  /// in [containerBuilder] because Figma uses opaque fills (e.g. `bgHoverDestructiveAlt`)
  /// instead of overlays.
  /// Tertiary regular: transparent — hover bg is set directly to `bgPrimaryHover`.
  /// Link: transparent — no hover background.
  Color _resolveHoverOverlayColor({required ZyraColors colors}) {
    return switch (widget.hierarchy) {
      ZyraButtonsSolidHierarchy.primary => widget.destructive ? colors.bgDestructiveHover : colors.bgBrandHover,
      // Primary Alt uses a translucent alpha overlay (alpha-white-10) that darkens
      // in light mode and lightens in dark mode — Figma does not define dedicated
      // hover/press background tokens for this hierarchy.
      ZyraButtonsSolidHierarchy.primaryAlt => colors.alphaWhite10,
      ZyraButtonsSolidHierarchy.secondary => widget.destructive ? Colors.transparent : colors.bgGrayHover,
      ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => Colors.transparent,
    };
  }

  /// Returns the overlay colour applied on press by [ZyraTappable].
  ///
  /// Regular primary/secondary: semi-transparent overlay on base bg.
  /// Destructive primary: `bgDestructivePressed`.
  /// Destructive secondary/tertiary: transparent — press bg handled via container.
  /// Tertiary regular: transparent — bg handles pressed state directly.
  /// Link: transparent — no press background.
  Color _resolvePressOverlayColor({required ZyraColors colors}) {
    return switch (widget.hierarchy) {
      ZyraButtonsSolidHierarchy.primary => widget.destructive ? colors.bgDestructivePressed : colors.bgBrandPressed,
      // Stronger alpha overlay on press for Primary Alt (alpha-white-20).
      ZyraButtonsSolidHierarchy.primaryAlt => colors.alphaWhite20,
      ZyraButtonsSolidHierarchy.secondary => widget.destructive ? Colors.transparent : colors.bgGrayPressed,
      // Tertiary: bg handles pressed state directly (no overlay needed).
      ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => Colors.transparent,
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
      ZyraButtonsSolidHierarchy.primary || ZyraButtonsSolidHierarchy.primaryAlt => 2.0,
      ZyraButtonsSolidHierarchy.secondary => 1.0,
      ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => 0.0,
    };
  }

  // ---------------------------------------------------------------------------
  // Token resolution helpers
  // ---------------------------------------------------------------------------

  Color _resolveBgColor({required ZyraColors colors, required Set<WidgetState> state}) {
    final isEnabled = !state.contains(WidgetState.disabled) || widget.isLoading;
    final isHovered = state.contains(WidgetState.hovered);
    final isPressed = state.contains(WidgetState.pressed);

    return switch (widget.hierarchy) {
      ZyraButtonsSolidHierarchy.primary => _primaryBgColor(
        colors: colors,
        isEnabled: isEnabled,
      ),
      ZyraButtonsSolidHierarchy.primaryAlt => _primaryAltBgColor(
        colors: colors,
        isEnabled: isEnabled,
      ),
      ZyraButtonsSolidHierarchy.secondary => _secondaryBgColor(
        colors: colors,
        isEnabled: isEnabled,
        isHovered: isHovered,
        isPressed: isPressed,
      ),
      ZyraButtonsSolidHierarchy.tertiary => _tertiaryBgColor(
        colors: colors,
        isEnabled: isEnabled,
        isHovered: isHovered,
        isPressed: isPressed,
      ),
      // Link uses the same press bg as tertiary for consistent tap feedback.
      ZyraButtonsSolidHierarchy.link => _linkBgColor(
        colors: colors,
        isEnabled: isEnabled,
        isPressed: isPressed,
      ),
    };
  }

  Color _primaryBgColor({required ZyraColors colors, required bool isEnabled}) {
    // Disabled: bg-disabled (same for both regular and destructive).
    if (!isEnabled) return colors.bgDisabled;
    // Enabled, hover, and loading all use the same base bg.
    // Hover/press darkening is handled by ZyraTappable overlay.
    return widget.destructive ? colors.bgErrorSolid : colors.bgBrandSolid;
  }

  Color _primaryAltBgColor({required ZyraColors colors, required bool isEnabled}) {
    // Disabled: bg-disabled (matches primary's disabled treatment).
    if (!isEnabled) return colors.bgDisabled;
    // Enabled / hover / pressed / loading all share the same base bg.
    // Hover/press tinting is handled by the alphaWhite10/20 overlays in
    // ZyraTappable rather than a bg colour swap.
    return colors.bgBrandPrimaryAlt;
  }

  Color _secondaryBgColor({
    required ZyraColors colors,
    required bool isEnabled,
    required bool isHovered,
    required bool isPressed,
  }) {
    if (!isEnabled) {
      // Disabled secondary uses bg-disabled for both regular and destructive.
      return colors.bgDisabled;
    }

    if (widget.destructive) {
      // Destructive secondary: pressed and hover use opaque bg colours directly
      // (no overlay). isPressed takes priority over isHovered.
      if (isPressed) return colors.bgDestructivePressedAlt;
      if (isHovered) return colors.bgDestructiveHoverAlt;
      // Default and loading: bg-primary (white).
      return colors.bgPrimary;
    }

    // Regular secondary: bg-primary_alt at rest. Hover darkening is handled by
    // the ZyraTappable overlay (bgPrimaryHover = rgba(0,0,0,0.16) composited
    // on top of bg-primary_alt).
    if (_isFocused) return colors.bgPrimary;
    return colors.bgPrimaryAlt;
  }

  Color _tertiaryBgColor({
    required ZyraColors colors,
    required bool isEnabled,
    required bool isHovered,
    required bool isPressed,
  }) {
    // Focused tertiary uses bg-primary (white) as a base.
    if (_isFocused) return colors.bgPrimary;

    if (widget.destructive) {
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
    required ZyraColors colors,
    required bool isEnabled,
    required bool isPressed,
  }) {
    // Link has no bg at rest or on hover. On press, use the same bg as tertiary
    // for consistent tap feedback across platforms (especially Android).
    if (!isPressed || !isEnabled) return Colors.transparent;
    return widget.destructive ? colors.bgDestructivePressedAlt : colors.bgGrayPressed;
  }

  Border? _resolveBorder({required ZyraColors colors, required Set<WidgetState> state}) {
    final isDisabled = state.contains(WidgetState.disabled);
    final isPressed = state.contains(WidgetState.pressed);
    if (isDisabled && !widget.isLoading) {
      return switch (widget.hierarchy) {
        ZyraButtonsSolidHierarchy.primary =>
          widget.destructive
              // Destructive primary disabled: fg-disabled_subtle border.
              ? Border.all(color: colors.fgDisabledSubtle, width: 1)
              // Regular primary disabled: border-disabled.
              : Border.all(color: colors.borderDisabled, width: 1),
        // Primary Alt disabled: border-disabled (matches primary regular disabled).
        // No destructive variant exists for primaryAlt.
        ZyraButtonsSolidHierarchy.primaryAlt => Border.all(color: colors.borderDisabled, width: 1),
        ZyraButtonsSolidHierarchy.secondary =>
          widget.destructive
              // Destructive secondary disabled: border-disabled_subtle.
              ? Border.all(color: colors.borderDisabledSubtle, width: 1)
              // Regular secondary disabled: border-disabled_subtle.
              : Border.all(color: colors.borderDisabledSubtle, width: 1),
        ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => null,
      };
    }

    return switch (widget.hierarchy) {
      // Primary: 2px semi-transparent white border (rgba(255,255,255,0.12) = alpha-white-10).
      ZyraButtonsSolidHierarchy.primary => Border.all(color: colors.alphaWhite10, width: 2),
      // Primary Alt: 2px alpha-white-10 at rest/hover; the pressed Figma variant
      // swaps the stroke to a solid border-primary stroke for stronger feedback.
      ZyraButtonsSolidHierarchy.primaryAlt => Border.all(
        color: isPressed ? colors.borderPrimary : colors.alphaWhite10,
        width: 2,
      ),
      ZyraButtonsSolidHierarchy.secondary =>
        widget.destructive
            // Destructive secondary: border-error_subtle for all active states.
            ? Border.all(color: colors.borderErrorSubtle, width: 1)
            // Regular secondary: border-primary on hover/focused; border-secondary at rest.
            : Border.all(
                color: (state.contains(WidgetState.hovered) || _isFocused)
                    ? colors.borderPrimary
                    : colors.borderSecondary,
                width: 1,
              ),
      ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => null,
    };
  }

  List<BoxShadow>? _resolveBoxShadows({required ZyraColors colors, required Set<WidgetState> state}) {
    final focusRingColor = widget.destructive ? colors.focusRingError : colors.focusRing;

    // Tertiary and link: 2-layer focus ring only when focused; no drop shadow ever.
    if (widget.hierarchy == ZyraButtonsSolidHierarchy.tertiary || widget.hierarchy == ZyraButtonsSolidHierarchy.link) {
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
        widget.hierarchy == ZyraButtonsSolidHierarchy.primary ||
        widget.hierarchy == ZyraButtonsSolidHierarchy.primaryAlt;
    final shadowColor = state.contains(WidgetState.hovered) && isPrimaryFamily
        ? colors.skeuomorphicShadow
        : colors.shadowXs;
    return [BoxShadow(color: shadowColor, offset: const Offset(0, 1), blurRadius: 2)];
  }

  TextStyle _resolveTextStyle({required ZyraDesignSystem zyra, required Set<WidgetState> state}) {
    final colors = zyra.colors;
    final textColor = _resolveTextColor(colors: colors, state: state);
    // sm: Medium weight (w500) per Figma. md/lg/xl: Bold (w700).
    final baseStyle = switch (widget.size) {
      ZyraButtonsSolidSize.sm => zyra.textTheme.textSm.medium,
      ZyraButtonsSolidSize.md => zyra.textTheme.textSm.bold,
      ZyraButtonsSolidSize.lg || ZyraButtonsSolidSize.xl => zyra.textTheme.textMd.bold,
    };
    // Link shows an underline on hover.
    final decoration = widget.hierarchy == ZyraButtonsSolidHierarchy.link && state.contains(WidgetState.hovered)
        ? TextDecoration.underline
        : null;
    return baseStyle.copyWith(color: textColor, decoration: decoration);
  }

  Color _resolveTextColor({required ZyraColors colors, required Set<WidgetState> state}) {
    final isDisabled = state.contains(WidgetState.disabled);
    final isHovered = state.contains(WidgetState.hovered);
    if (isDisabled && !widget.isLoading) {
      return switch (widget.hierarchy) {
        // Primary disabled: fg-disabled for both regular and destructive.
        ZyraButtonsSolidHierarchy.primary => colors.fgDisabled,
        // Primary Alt disabled: fg-disabled (matches primary's disabled treatment).
        ZyraButtonsSolidHierarchy.primaryAlt => colors.fgDisabled,
        // Secondary disabled: text-disabled (regular), text-disabled (destructive).
        ZyraButtonsSolidHierarchy.secondary => colors.textDisabled,
        // Tertiary disabled: fg-disabled.
        ZyraButtonsSolidHierarchy.tertiary => colors.fgDisabled,
        // Link disabled: fg-disabled.
        ZyraButtonsSolidHierarchy.link => colors.fgDisabled,
      };
    }

    if (widget.destructive) {
      return switch (widget.hierarchy) {
        // Destructive primary: always text-white.
        ZyraButtonsSolidHierarchy.primary => colors.textWhite,
        // Unreachable — assertion in constructor blocks primaryAlt + destructive.
        ZyraButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
        // Destructive secondary: text-error-primary at rest, text-error-primary_hover on hover.
        ZyraButtonsSolidHierarchy.secondary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        // Destructive tertiary: text-error-primary at rest, text-error-primary_hover on hover.
        ZyraButtonsSolidHierarchy.tertiary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        // Destructive link: text-error-primary at rest, text-error-primary_hover on hover.
        ZyraButtonsSolidHierarchy.link => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
      };
    }

    return switch (widget.hierarchy) {
      ZyraButtonsSolidHierarchy.primary => colors.textWhite,
      // Primary Alt: text-primary_on-white (dark on a brand-tinted/light bg).
      // No hover change — overlay handles the hover/press feedback.
      ZyraButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
      // Secondary text colour does not change on hover (only background does).
      ZyraButtonsSolidHierarchy.secondary => colors.textSecondary,
      ZyraButtonsSolidHierarchy.tertiary => colors.textTertiary,
      ZyraButtonsSolidHierarchy.link => isHovered ? colors.textBrandSecondaryHover : colors.textBrandSecondary,
    };
  }

  Color _resolveIconColor({required ZyraColors colors, required Set<WidgetState> state}) {
    final isDisabled = state.contains(WidgetState.disabled);
    final isHovered = state.contains(WidgetState.hovered);
    if (isDisabled && !widget.isLoading) {
      // Disabled icon colour: fg-disabled for primary, text-disabled for secondary,
      // fg-disabled for tertiary/link.
      return switch (widget.hierarchy) {
        ZyraButtonsSolidHierarchy.primary => colors.fgDisabled,
        ZyraButtonsSolidHierarchy.primaryAlt => colors.fgDisabled,
        ZyraButtonsSolidHierarchy.secondary => colors.textDisabled,
        ZyraButtonsSolidHierarchy.tertiary || ZyraButtonsSolidHierarchy.link => colors.fgDisabled,
      };
    }

    if (widget.destructive) {
      return switch (widget.hierarchy) {
        ZyraButtonsSolidHierarchy.primary => colors.textWhite,
        // Unreachable — assertion in constructor blocks primaryAlt + destructive.
        ZyraButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
        ZyraButtonsSolidHierarchy.secondary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        ZyraButtonsSolidHierarchy.tertiary => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
        ZyraButtonsSolidHierarchy.link => isHovered ? colors.textErrorPrimaryHover : colors.textErrorPrimary,
      };
    }

    return switch (widget.hierarchy) {
      // Primary (regular) always uses text-white for the icon.
      ZyraButtonsSolidHierarchy.primary => colors.textWhite,
      // Primary Alt: icon matches the dark text colour (text-primary_on-white).
      ZyraButtonsSolidHierarchy.primaryAlt => colors.textPrimaryOnWhite,
      // Secondary and tertiary icon color is static across all active states (no hover change).
      ZyraButtonsSolidHierarchy.secondary => colors.textSecondary,
      ZyraButtonsSolidHierarchy.tertiary => colors.textTertiary,
      // Link uses text-brand-secondary tokens on default/hover; text-secondary when focused.
      ZyraButtonsSolidHierarchy.link =>
        _isFocused ? colors.textSecondary : (isHovered ? colors.textBrandSecondaryHover : colors.textBrandSecondary),
    };
  }

  EdgeInsetsDirectional _resolvePadding() => switch (widget.size) {
    // sm: 12px horizontal (spacing-lg) per Figma — differs from md's 14px.
    ZyraButtonsSolidSize.sm => const EdgeInsetsDirectional.symmetric(
      horizontal: ZyraSpacing.lg,
      vertical: ZyraSpacing.md,
    ),
    ZyraButtonsSolidSize.md => const EdgeInsetsDirectional.symmetric(
      horizontal: _buttonHPaddingMd,
      vertical: _buttonVPaddingMd,
    ),
    ZyraButtonsSolidSize.lg => const EdgeInsetsDirectional.symmetric(
      horizontal: ZyraSpacing.xl,
      vertical: ZyraSpacing.lg,
    ),
    ZyraButtonsSolidSize.xl => const EdgeInsetsDirectional.symmetric(
      horizontal: ZyraSpacing.x2l,
      vertical: ZyraSpacing.xl,
    ),
  };

  EdgeInsetsDirectional _resolveIconOnlyPadding() => switch (widget.size) {
    ZyraButtonsSolidSize.sm => const EdgeInsetsDirectional.all(ZyraSpacing.md),
    ZyraButtonsSolidSize.md => const EdgeInsetsDirectional.all(_buttonVPaddingMd),
    ZyraButtonsSolidSize.lg => const EdgeInsetsDirectional.all(ZyraSpacing.lg),
    ZyraButtonsSolidSize.xl => const EdgeInsetsDirectional.all(ZyraSpacing.xl),
  };

  double _resolveGap() => switch (widget.size) {
    ZyraButtonsSolidSize.sm || ZyraButtonsSolidSize.md => ZyraSpacing.xs,
    ZyraButtonsSolidSize.lg || ZyraButtonsSolidSize.xl => ZyraSpacing.sm,
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
