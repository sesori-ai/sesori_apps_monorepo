// GENERATED CODE - DO NOT MODIFY BY HAND
// To update, export variables from Figma and run:
//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate
// ignore_for_file: lines_longer_than_80_chars

import "package:flutter/material.dart";

import "../../utils/lerp_utils.dart";
import "zyra_color_primitives.g.dart";

/// Dark mode color tokens matching Figma specifications.
///
/// All colors are static const, enabling compile-time constant expressions.
/// Colors reference [ZyraColorPrimitives] where Figma uses an alias,
/// or inline hex where Figma uses a direct value.
abstract final class ZyraColorsDark {
  // ===========================================================================
  // Text Colors - Figma: Colors/Text/*
  // ===========================================================================

  /// Figma: Colors/Text/text-brand-primary (900) → Gray (dark mode)/50
  static const Color textBrandPrimary = ZyraColorPrimitives.grayDark50;

  /// Figma: Colors/Text/text-brand-secondary (700) → Gray (dark mode)/300
  static const Color textBrandSecondary = ZyraColorPrimitives.grayDark300;

  /// Figma: Colors/Text/text-brand-secondary_hover → Gray (dark mode)/200
  static const Color textBrandSecondaryHover = ZyraColorPrimitives.grayDark200;

  /// Figma: Colors/Text/text-brand-tertiary (600) → Gray (dark mode)/400
  static const Color textBrandTertiary = ZyraColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-brand-tertiary_alt → Brand Blue/200
  static const Color textBrandTertiaryAlt = ZyraColorPrimitives.brandBlue200;

  /// Figma: Colors/Text/text-disabled → Gray (dark mode)/500
  static const Color textDisabled = ZyraColorPrimitives.grayDark500;

  /// Figma: Colors/Text/text-error-primary (600) → Error/400
  static const Color textErrorPrimary = ZyraColorPrimitives.error400;

  /// Figma: Colors/Text/text-error-primary_hover → Error/300
  static const Color textErrorPrimaryHover = ZyraColorPrimitives.error300;

  /// Figma: Colors/Text/text-placeholder → Gray (dark mode)/600
  static const Color textPlaceholder = ZyraColorPrimitives.grayDark600;

  /// Figma: Colors/Text/text-placeholder_subtle → Gray (dark mode)/700
  static const Color textPlaceholderSubtle = ZyraColorPrimitives.grayDark700;

  /// Figma: Colors/Text/text-primary (900) → Gray (dark mode)/25
  static const Color textPrimary = ZyraColorPrimitives.grayDark25;

  /// Figma: Colors/Text/text-primary_on-brand → Gray (dark mode)/50
  static const Color textPrimaryOnBrand = ZyraColorPrimitives.grayDark50;

  /// Figma: Colors/Text/text-primary_on-white
  static const Color textPrimaryOnWhite = Color(0xFF0A0D12);

  /// Figma: Colors/Text/text-quaternary (500) → Gray (dark mode)/400
  static const Color textQuaternary = ZyraColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-quaternary_on-brand → Gray (dark mode)/400
  static const Color textQuaternaryOnBrand = ZyraColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-secondary (600) → Gray (dark mode)/400
  static const Color textSecondary = ZyraColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-secondary_hover → Gray (dark mode)/200
  static const Color textSecondaryHover = ZyraColorPrimitives.grayDark200;

  /// Figma: Colors/Text/text-secondary_on-brand → Base/white
  static const Color textSecondaryOnBrand = ZyraColorPrimitives.baseWhite;

  /// Figma: Colors/Text/text-success-primary (600) → Success/400
  static const Color textSuccessPrimary = ZyraColorPrimitives.success400;

  /// Figma: Colors/Text/text-tertiary (600) → Gray (light mode)/400
  static const Color textTertiary = ZyraColorPrimitives.grayLight400;

  /// Figma: Colors/Text/text-tertiary_hover → Gray (dark mode)/300
  static const Color textTertiaryHover = ZyraColorPrimitives.grayDark300;

  /// Figma: Colors/Text/text-tertiary_on-brand → Gray (dark mode)/400
  static const Color textTertiaryOnBrand = ZyraColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-warning-primary (600) → Warning/400
  static const Color textWarningPrimary = ZyraColorPrimitives.warning400;

  /// Figma: Colors/Text/text-white → Base/white
  static const Color textWhite = ZyraColorPrimitives.baseWhite;

  // ===========================================================================
  // Border Colors - Figma: Colors/Border/*
  // ===========================================================================

  /// Figma: Colors/Border/border-brand → Brand Blue/400
  static const Color borderBrand = ZyraColorPrimitives.brandBlue400;

  /// Figma: Colors/Border/border-brand_alt → Gray (dark mode)/700
  static const Color borderBrandAlt = ZyraColorPrimitives.grayDark700;

  /// Figma: Colors/Border/border-disabled → Gray (dark mode)/700
  static const Color borderDisabled = ZyraColorPrimitives.grayDark700;

  /// Figma: Colors/Border/border-disabled_subtle → Gray (dark mode)/800
  static const Color borderDisabledSubtle = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Border/border-error → Error/400
  static const Color borderError = ZyraColorPrimitives.error400;

  /// Figma: Colors/Border/border-error_subtle → Error/500
  static const Color borderErrorSubtle = ZyraColorPrimitives.error500;

  /// Figma: Colors/Border/border-inside-reversed-bottom
  static const Color borderInsideReversedBottom = Color(0x008D939C);

  /// Figma: Colors/Border/border-inside-reversed-top
  static const Color borderInsideReversedTop = Color(0xFF303236);

  /// Figma: Colors/Border/border-primary → Gray (dark mode)/700
  static const Color borderPrimary = ZyraColorPrimitives.grayDark700;

  /// Figma: Colors/Border/border-reversed → Gray (dark mode)/800
  static const Color borderReversed = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Border/border-secondary → Gray (dark mode)/800
  static const Color borderSecondary = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Border/border-secondary_alt → Base/black
  static const Color borderSecondaryAlt = ZyraColorPrimitives.baseBlack;

  /// Figma: Colors/Border/border-tertiary → Gray (dark mode)/800
  static const Color borderTertiary = ZyraColorPrimitives.grayDark800;

  // ===========================================================================
  // Foreground Colors - Figma: Colors/Foreground/*
  // ===========================================================================

  /// Figma: Colors/Foreground/fg-brand-primary (600) → Brand Blue/500
  static const Color fgBrandPrimary = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-brand-primary_alt → Gray (dark mode)/300
  static const Color fgBrandPrimaryAlt = ZyraColorPrimitives.grayDark300;

  /// Figma: Colors/Foreground/fg-brand-secondary (500) → Gray (dark mode)/500
  static const Color fgBrandSecondary = ZyraColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-brand-secondary_alt → Gray (dark mode)/600
  static const Color fgBrandSecondaryAlt = ZyraColorPrimitives.grayDark600;

  /// Figma: Colors/Foreground/fg-brand-secondary_hover → Gray (dark mode)/500
  static const Color fgBrandSecondaryHover = ZyraColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-disabled → Gray (dark mode)/500
  static const Color fgDisabled = ZyraColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-disabled_subtle → Gray (dark mode)/600
  static const Color fgDisabledSubtle = ZyraColorPrimitives.grayDark600;

  /// Figma: Colors/Foreground/fg-error-primary → Error/500
  static const Color fgErrorPrimary = ZyraColorPrimitives.error500;

  /// Figma: Colors/Foreground/fg-error-secondary → Error/400
  static const Color fgErrorSecondary = ZyraColorPrimitives.error400;

  /// Figma: Colors/Foreground/fg-primary (900) → Base/white
  static const Color fgPrimary = ZyraColorPrimitives.baseWhite;

  /// Figma: Colors/Foreground/fg-quaternary (400) → Gray (dark mode)/600
  static const Color fgQuaternary = ZyraColorPrimitives.grayDark600;

  /// Figma: Colors/Foreground/fg-quaternary_hover → Gray (dark mode)/500
  static const Color fgQuaternaryHover = ZyraColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-secondary (700) → Gray (dark mode)/300
  static const Color fgSecondary = ZyraColorPrimitives.grayDark300;

  /// Figma: Colors/Foreground/fg-secondary_hover → Gray (dark mode)/200
  static const Color fgSecondaryHover = ZyraColorPrimitives.grayDark200;

  /// Figma: Colors/Foreground/fg-success-primary → Success/500
  static const Color fgSuccessPrimary = ZyraColorPrimitives.success500;

  /// Figma: Colors/Foreground/fg-success-secondary → Success/400
  static const Color fgSuccessSecondary = ZyraColorPrimitives.success400;

  /// Figma: Colors/Foreground/fg-tertiary (600) → Gray (dark mode)/400
  static const Color fgTertiary = ZyraColorPrimitives.grayDark400;

  /// Figma: Colors/Foreground/fg-tertiary_hover → Gray (dark mode)/300
  static const Color fgTertiaryHover = ZyraColorPrimitives.grayDark300;

  /// Figma: Colors/Foreground/fg-warning-primary → Warning/500
  static const Color fgWarningPrimary = ZyraColorPrimitives.warning500;

  /// Figma: Colors/Foreground/fg-warning-secondary → Warning/400
  static const Color fgWarningSecondary = ZyraColorPrimitives.warning400;

  /// Figma: Colors/Foreground/fg-white → Base/white
  static const Color fgWhite = ZyraColorPrimitives.baseWhite;

  // ===========================================================================
  // Background Colors - Figma: Colors/Background/*
  // ===========================================================================

  /// Figma: Colors/Background/Black-white-inversed (alpha) → Base/transparent black
  static const Color blackWhiteInversed = ZyraColorPrimitives.baseTransparentBlack;

  /// Figma: Colors/Background/bg-active → Gray (dark mode)/800
  static const Color bgActive = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-brand-primary → Brand Blue/500
  static const Color bgBrandPrimary = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Background/bg-brand-primary_alt → Background/bg-secondary
  static const Color bgBrandPrimaryAlt = ZyraColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-brand-secondary → Brand Blue/600
  static const Color bgBrandSecondary = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Background/bg-brand-section → Background/bg-secondary
  static const Color bgBrandSection = ZyraColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-brand-section_subtle → Gray (dark mode)/950
  static const Color bgBrandSectionSubtle = ZyraColorPrimitives.grayDark950;

  /// Figma: Colors/Background/bg-brand-solid → Brand Blue/600
  static const Color bgBrandSolid = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Background/bg-brand-solid_hover → Brand Blue/500
  static const Color bgBrandSolidHover = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Background/bg-brand_hover → Gray (dark mode alpha)/700
  static const Color bgBrandHover = ZyraColorPrimitives.grayDarkAlpha700;

  /// Figma: Colors/Background/bg-brand_pressed → Gray (dark mode alpha)/500
  static const Color bgBrandPressed = ZyraColorPrimitives.grayDarkAlpha500;

  /// Figma: Colors/Background/bg-destructive_hover → Gray (dark mode alpha)/900
  static const Color bgDestructiveHover = ZyraColorPrimitives.grayDarkAlpha900;

  /// Figma: Colors/Background/bg-destructive_pressed → Gray (dark mode alpha)/700
  static const Color bgDestructivePressed = ZyraColorPrimitives.grayDarkAlpha700;

  /// Figma: Colors/Background/bg-disabled → Gray (dark mode)/800
  static const Color bgDisabled = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-disabled_subtle → Gray (dark mode)/900
  static const Color bgDisabledSubtle = ZyraColorPrimitives.grayDark900;

  /// Figma: Colors/Background/bg-error-primary → Error/950
  static const Color bgErrorPrimary = ZyraColorPrimitives.error950;

  /// Figma: Colors/Background/bg-error-secondary → Error/600
  static const Color bgErrorSecondary = ZyraColorPrimitives.error600;

  /// Figma: Colors/Background/bg-error-solid → Error/600
  static const Color bgErrorSolid = ZyraColorPrimitives.error600;

  /// Figma: Colors/Background/bg-error-solid_hover → Error/500
  static const Color bgErrorSolidHover = ZyraColorPrimitives.error500;

  /// Figma: Colors/Background/bg-gray_hover → Gray (dark mode alpha)/800
  static const Color bgGrayHover = ZyraColorPrimitives.grayDarkAlpha800;

  /// Figma: Colors/Background/bg-gray_pressed → Gray (dark mode alpha)/600
  static const Color bgGrayPressed = ZyraColorPrimitives.grayDarkAlpha600;

  /// Figma: Colors/Background/bg-overlay → Gray (dark mode)/800
  static const Color bgOverlay = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-primary → Gray (dark mode)/950
  static const Color bgPrimary = ZyraColorPrimitives.grayDark950;

  /// Figma: Colors/Background/bg-primary-solid → Background/bg-secondary
  static const Color bgPrimarySolid = ZyraColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-primary_alt → Background/bg-secondary
  static const Color bgPrimaryAlt = ZyraColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-quaternary → Gray (dark mode)/700
  static const Color bgQuaternary = ZyraColorPrimitives.grayDark700;

  /// Figma: Colors/Background/bg-secondary → Gray (dark mode)/900
  static const Color bgSecondary = ZyraColorPrimitives.grayDark900;

  /// Figma: Colors/Background/bg-secondary-solid → Gray (dark mode)/600
  static const Color bgSecondarySolid = ZyraColorPrimitives.grayDark600;

  /// Figma: Colors/Background/bg-secondary_alt → Background/bg-primary
  static const Color bgSecondaryAlt = ZyraColorsDark.bgPrimary;

  /// Figma: Colors/Background/bg-secondary_hover → Gray (dark mode)/800
  static const Color bgSecondaryHover = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-secondary_subtle → Gray (dark mode)/900
  static const Color bgSecondarySubtle = ZyraColorPrimitives.grayDark900;

  /// Figma: Colors/Background/bg-success-primary → Success/950
  static const Color bgSuccessPrimary = ZyraColorPrimitives.success950;

  /// Figma: Colors/Background/bg-success-secondary → Success/500
  static const Color bgSuccessSecondary = ZyraColorPrimitives.success500;

  /// Figma: Colors/Background/bg-success-solid → Success/600
  static const Color bgSuccessSolid = ZyraColorPrimitives.success600;

  /// Figma: Colors/Background/bg-tertiary → Gray (dark mode)/800
  static const Color bgTertiary = ZyraColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-warning-primary → Warning/950
  static const Color bgWarningPrimary = ZyraColorPrimitives.warning950;

  /// Figma: Colors/Background/bg-warning-secondary → Warning/600
  static const Color bgWarningSecondary = ZyraColorPrimitives.warning600;

  /// Figma: Colors/Background/bg-warning-solid → Warning/500
  static const Color bgWarningSolid = ZyraColorPrimitives.warning500;

  /// Figma: Colors/Background/bg_destructive_hover_alt → Error/950
  static const Color bgDestructiveHoverAlt = ZyraColorPrimitives.error950;

  /// Figma: Colors/Background/bg_destructive_pressed_alt → Error/800
  static const Color bgDestructivePressedAlt = ZyraColorPrimitives.error800;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/*
  // ===========================================================================

  /// Figma: Colors/Effects/Focus rings/focus-ring → Brand Blue/500
  static const Color focusRing = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Effects/Focus rings/focus-ring-error → Error/500
  static const Color focusRingError = ZyraColorPrimitives.error500;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/Shadows/*
  // ===========================================================================

  /// Figma: Colors/Effects/Shadows/shadow-2xl_01 → Base/transparent
  static const Color shadow2xl01 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-2xl_02 → Base/transparent
  static const Color shadow2xl02 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-3xl_01 → Base/transparent
  static const Color shadow3xl01 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-3xl_02 → Base/transparent
  static const Color shadow3xl02 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-inversed → Gray (light mode alpha)/200
  static const Color shadowInversed = ZyraColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Effects/Shadows/shadow-lg_01 → Base/transparent
  static const Color shadowLg01 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-lg_02 → Base/transparent
  static const Color shadowLg02 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-lg_03 → Base/transparent
  static const Color shadowLg03 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-md_01 → Base/transparent
  static const Color shadowMd01 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-md_02 → Base/transparent
  static const Color shadowMd02 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic
  static const Color skeuomorphicShadow = Color(0x0D0C0E12);

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic-inner-border
  static const Color skeuomorphicInnerBorder = Color(0x2E0C0E12);

  /// Figma: Colors/Effects/Shadows/shadow-sm_01 → Base/transparent
  static const Color shadowSm01 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-sm_02 → Base/transparent
  static const Color shadowSm02 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xl_01 → Base/transparent
  static const Color shadowXl01 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xl_02 → Base/transparent
  static const Color shadowXl02 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xl_03 → Base/transparent
  static const Color shadowXl03 = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xs → Base/transparent
  static const Color shadowXs = ZyraColorPrimitives.baseTransparent;

  // ===========================================================================
  // Component Colors - Buttons
  // ===========================================================================

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon → Error/300
  static const Color buttonDestructivePrimaryIcon = ZyraColorPrimitives.error300;

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon_hover → Error/200
  static const Color buttonDestructivePrimaryIconHover = ZyraColorPrimitives.error200;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-background → Gray (dark mode alpha)/900
  static const Color buttonGlassPrimaryBackground = ZyraColorPrimitives.grayDarkAlpha900;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-hover → Gray (dark mode alpha)/800
  static const Color buttonGlassPrimaryHover = ZyraColorPrimitives.grayDarkAlpha800;

  /// Figma: Component colors/Components/Buttons/button-primary-icon → Brand Blue/300
  static const Color buttonPrimaryIcon = ZyraColorPrimitives.brandBlue300;

  /// Figma: Component colors/Components/Buttons/button-primary-icon_hover → Brand Blue/200
  static const Color buttonPrimaryIconHover = ZyraColorPrimitives.brandBlue200;

  // ===========================================================================
  // Component Colors - Icons
  // ===========================================================================

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand → Gray (dark mode)/400
  static const Color iconFgBrand = ZyraColorPrimitives.grayDark400;

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand_on-brand → Gray (dark mode)/400
  static const Color iconFgBrandOnBrand = ZyraColorPrimitives.grayDark400;

  // ===========================================================================
  // Component Colors - Alpha (mode-invariant)
  // ===========================================================================

  /// Figma: Component colors/Alpha/alpha-black-10
  static const Color alphaBlack10 = Color(0x1AFFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-20
  static const Color alphaBlack20 = Color(0x33FFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-30
  static const Color alphaBlack30 = Color(0x4DFFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-40
  static const Color alphaBlack40 = Color(0x66FFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-50
  static const Color alphaBlack50 = Color(0x80FFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-60
  static const Color alphaBlack60 = Color(0x99FFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-70
  static const Color alphaBlack70 = Color(0xB2FFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-80
  static const Color alphaBlack80 = Color(0xCCFFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-90
  static const Color alphaBlack90 = Color(0xE5FFFFFF);

  /// Figma: Component colors/Alpha/alpha-black-100
  static const Color alphaBlack100 = Color(0xFFFFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-10
  static const Color alphaWhite10 = Color(0x1A0C0E12);

  /// Figma: Component colors/Alpha/alpha-white-20
  static const Color alphaWhite20 = Color(0x330C0E12);

  /// Figma: Component colors/Alpha/alpha-white-30
  static const Color alphaWhite30 = Color(0x4D0C0E12);

  /// Figma: Component colors/Alpha/alpha-white-40
  static const Color alphaWhite40 = Color(0x660C0E12);

  /// Figma: Component colors/Alpha/alpha-white-50
  static const Color alphaWhite50 = Color(0x800C0E12);

  /// Figma: Component colors/Alpha/alpha-white-60
  static const Color alphaWhite60 = Color(0x990C0E12);

  /// Figma: Component colors/Alpha/alpha-white-70
  static const Color alphaWhite70 = Color(0xB20C0E12);

  /// Figma: Component colors/Alpha/alpha-white-80
  static const Color alphaWhite80 = Color(0xCC0C0E12);

  /// Figma: Component colors/Alpha/alpha-white-90
  static const Color alphaWhite90 = Color(0xE50C0E12);

  /// Figma: Component colors/Alpha/alpha-white-100 → Gray (dark mode)/950
  static const Color alphaWhite100 = ZyraColorPrimitives.grayDark950;

  // ===========================================================================
  // Utility Colors
  // ===========================================================================

  /// Figma: Component colors/Utility/Blue/utility-blue-50 → Brand Blue/900
  static const Color utilityBlue50 = ZyraColorPrimitives.brandBlue900;

  /// Figma: Component colors/Utility/Blue/utility-blue-100 → Brand Blue/800
  static const Color utilityBlue100 = ZyraColorPrimitives.brandBlue800;

  /// Figma: Component colors/Utility/Blue/utility-blue-200 → Brand Blue/700
  static const Color utilityBlue200 = ZyraColorPrimitives.brandBlue700;

  /// Figma: Component colors/Utility/Blue/utility-blue-300 → Brand Blue/600
  static const Color utilityBlue300 = ZyraColorPrimitives.brandBlue600;

  /// Figma: Component colors/Utility/Blue/utility-blue-400 → Brand Blue/500
  static const Color utilityBlue400 = ZyraColorPrimitives.brandBlue500;

  /// Figma: Component colors/Utility/Blue/utility-blue-500 → Brand Blue/400
  static const Color utilityBlue500 = ZyraColorPrimitives.brandBlue400;

  /// Figma: Component colors/Utility/Blue/utility-blue-600 → Brand Blue/300
  static const Color utilityBlue600 = ZyraColorPrimitives.brandBlue300;

  /// Figma: Component colors/Utility/Blue/utility-blue-700 → Brand Blue/200
  static const Color utilityBlue700 = ZyraColorPrimitives.brandBlue200;

  /// Figma: Component colors/Utility/Error/utility-error-50 → Error/950
  static const Color utilityError50 = ZyraColorPrimitives.error950;

  /// Figma: Component colors/Utility/Error/utility-error-100 → Error/900
  static const Color utilityError100 = ZyraColorPrimitives.error900;

  /// Figma: Component colors/Utility/Error/utility-error-200 → Error/800
  static const Color utilityError200 = ZyraColorPrimitives.error800;

  /// Figma: Component colors/Utility/Error/utility-error-300 → Error/700
  static const Color utilityError300 = ZyraColorPrimitives.error700;

  /// Figma: Component colors/Utility/Error/utility-error-400 → Error/600
  static const Color utilityError400 = ZyraColorPrimitives.error600;

  /// Figma: Component colors/Utility/Error/utility-error-500 → Error/500
  static const Color utilityError500 = ZyraColorPrimitives.error500;

  /// Figma: Component colors/Utility/Error/utility-error-600 → Error/400
  static const Color utilityError600 = ZyraColorPrimitives.error400;

  /// Figma: Component colors/Utility/Error/utility-error-700 → Error/300
  static const Color utilityError700 = ZyraColorPrimitives.error300;

  /// Figma: Component colors/Utility/Success/utility-success-50 → Success/950
  static const Color utilitySuccess50 = ZyraColorPrimitives.success950;

  /// Figma: Component colors/Utility/Success/utility-success-100 → Success/900
  static const Color utilitySuccess100 = ZyraColorPrimitives.success900;

  /// Figma: Component colors/Utility/Success/utility-success-200 → Success/800
  static const Color utilitySuccess200 = ZyraColorPrimitives.success800;

  /// Figma: Component colors/Utility/Success/utility-success-300 → Success/700
  static const Color utilitySuccess300 = ZyraColorPrimitives.success700;

  /// Figma: Component colors/Utility/Success/utility-success-400 → Success/600
  static const Color utilitySuccess400 = ZyraColorPrimitives.success600;

  /// Figma: Component colors/Utility/Success/utility-success-500 → Success/500
  static const Color utilitySuccess500 = ZyraColorPrimitives.success500;

  /// Figma: Component colors/Utility/Success/utility-success-600 → Success/400
  static const Color utilitySuccess600 = ZyraColorPrimitives.success400;

  /// Figma: Component colors/Utility/Success/utility-success-700 → Success/300
  static const Color utilitySuccess700 = ZyraColorPrimitives.success300;

  /// Figma: Component colors/Utility/Warning/utility-warning-50 → Warning/950
  static const Color utilityWarning50 = ZyraColorPrimitives.warning950;

  /// Figma: Component colors/Utility/Warning/utility-warning-100 → Warning/900
  static const Color utilityWarning100 = ZyraColorPrimitives.warning900;

  /// Figma: Component colors/Utility/Warning/utility-warning-200 → Warning/800
  static const Color utilityWarning200 = ZyraColorPrimitives.warning800;

  /// Figma: Component colors/Utility/Warning/utility-warning-300 → Warning/700
  static const Color utilityWarning300 = ZyraColorPrimitives.warning700;

  /// Figma: Component colors/Utility/Warning/utility-warning-400 → Warning/600
  static const Color utilityWarning400 = ZyraColorPrimitives.warning600;

  /// Figma: Component colors/Utility/Warning/utility-warning-500 → Warning/500
  static const Color utilityWarning500 = ZyraColorPrimitives.warning500;

  /// Figma: Component colors/Utility/Warning/utility-warning-600 → Warning/400
  static const Color utilityWarning600 = ZyraColorPrimitives.warning400;

  /// Figma: Component colors/Utility/Warning/utility-warning-700 → Warning/300
  static const Color utilityWarning700 = ZyraColorPrimitives.warning300;

  // ===========================================================================
  // Other
  // ===========================================================================

  /// Figma: Component colors/Components/Avatars/avatar-styles-bg-neutral
  static const Color avatarStylesBgNeutral = Color(0xFFE0E0E0);

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-brand → Brand Blue/200
  static const Color featuredIconLightFgBrand = ZyraColorPrimitives.brandBlue200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-error → Error/200
  static const Color featuredIconLightFgError = ZyraColorPrimitives.error200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-gray → Gray (dark mode alpha)/200
  static const Color featuredIconLightFgGray = ZyraColorPrimitives.grayDarkAlpha200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-success → Success/200
  static const Color featuredIconLightFgSuccess = ZyraColorPrimitives.success200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-warning → Warning/200
  static const Color featuredIconLightFgWarning = ZyraColorPrimitives.warning200;

  /// Figma: Component colors/Components/Icons/Main Avatar/gradient-bottom → Brand Blue/300
  static const Color gradientBottom = ZyraColorPrimitives.brandBlue300;

  /// Figma: Component colors/Components/Icons/Main Avatar/gradient-top → Base/white
  static const Color gradientTop = ZyraColorPrimitives.baseWhite;

  /// Figma: Component colors/Components/Toggles/toggle-border → Base/transparent
  static const Color toggleBorder = ZyraColorPrimitives.baseTransparent;

  /// Figma: Component colors/Components/Toggles/toggle-button-fg_disabled → Gray (dark mode)/600
  static const Color toggleButtonFgDisabled = ZyraColorPrimitives.grayDark600;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed → Base/transparent
  static const Color toggleSlimBorderPressed = ZyraColorPrimitives.baseTransparent;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed-hover → Base/transparent
  static const Color toggleSlimBorderPressedHover = ZyraColorPrimitives.baseTransparent;
}

/// Light mode color tokens matching Figma specifications.
///
/// All colors are static const, enabling compile-time constant expressions.
/// Colors reference [ZyraColorPrimitives] where Figma uses an alias,
/// or inline hex where Figma uses a direct value.
abstract final class ZyraColorsLight {
  // ===========================================================================
  // Text Colors - Figma: Colors/Text/*
  // ===========================================================================

  /// Figma: Colors/Text/text-brand-primary (900) → Brand Blue/900
  static const Color textBrandPrimary = ZyraColorPrimitives.brandBlue900;

  /// Figma: Colors/Text/text-brand-secondary (700) → Brand Blue/700
  static const Color textBrandSecondary = ZyraColorPrimitives.brandBlue700;

  /// Figma: Colors/Text/text-brand-secondary_hover → Brand Blue/800
  static const Color textBrandSecondaryHover = ZyraColorPrimitives.brandBlue800;

  /// Figma: Colors/Text/text-brand-tertiary (600) → Brand Blue/600
  static const Color textBrandTertiary = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Text/text-brand-tertiary_alt → Brand Blue/600
  static const Color textBrandTertiaryAlt = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Text/text-disabled → Gray (light mode)/500
  static const Color textDisabled = ZyraColorPrimitives.grayLight500;

  /// Figma: Colors/Text/text-error-primary (600) → Error/600
  static const Color textErrorPrimary = ZyraColorPrimitives.error600;

  /// Figma: Colors/Text/text-error-primary_hover → Error/700
  static const Color textErrorPrimaryHover = ZyraColorPrimitives.error700;

  /// Figma: Colors/Text/text-placeholder → Gray (light mode)/400
  static const Color textPlaceholder = ZyraColorPrimitives.grayLight400;

  /// Figma: Colors/Text/text-placeholder_subtle → Gray (light mode)/300
  static const Color textPlaceholderSubtle = ZyraColorPrimitives.grayLight300;

  /// Figma: Colors/Text/text-primary (900) → Gray (light mode)/950
  static const Color textPrimary = ZyraColorPrimitives.grayLight950;

  /// Figma: Colors/Text/text-primary_on-brand → Base/white
  static const Color textPrimaryOnBrand = ZyraColorPrimitives.baseWhite;

  /// Figma: Colors/Text/text-primary_on-white
  static const Color textPrimaryOnWhite = Color(0xFF0A0D12);

  /// Figma: Colors/Text/text-quaternary (500) → Gray (light mode)/400
  static const Color textQuaternary = ZyraColorPrimitives.grayLight400;

  /// Figma: Colors/Text/text-quaternary_on-brand → Brand Blue/300
  static const Color textQuaternaryOnBrand = ZyraColorPrimitives.brandBlue300;

  /// Figma: Colors/Text/text-secondary (600) → Gray (light mode)/700
  static const Color textSecondary = ZyraColorPrimitives.grayLight700;

  /// Figma: Colors/Text/text-secondary_hover → Gray (light mode)/800
  static const Color textSecondaryHover = ZyraColorPrimitives.grayLight800;

  /// Figma: Colors/Text/text-secondary_on-brand → Brand Blue/400
  static const Color textSecondaryOnBrand = ZyraColorPrimitives.brandBlue400;

  /// Figma: Colors/Text/text-success-primary (600) → Success/600
  static const Color textSuccessPrimary = ZyraColorPrimitives.success600;

  /// Figma: Colors/Text/text-tertiary (600) → Gray (light mode)/600
  static const Color textTertiary = ZyraColorPrimitives.grayLight600;

  /// Figma: Colors/Text/text-tertiary_hover → Gray (light mode)/700
  static const Color textTertiaryHover = ZyraColorPrimitives.grayLight700;

  /// Figma: Colors/Text/text-tertiary_on-brand → Brand Blue/200
  static const Color textTertiaryOnBrand = ZyraColorPrimitives.brandBlue200;

  /// Figma: Colors/Text/text-warning-primary (600) → Warning/600
  static const Color textWarningPrimary = ZyraColorPrimitives.warning600;

  /// Figma: Colors/Text/text-white → Base/white
  static const Color textWhite = ZyraColorPrimitives.baseWhite;

  // ===========================================================================
  // Border Colors - Figma: Colors/Border/*
  // ===========================================================================

  /// Figma: Colors/Border/border-brand → Brand Blue/500
  static const Color borderBrand = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Border/border-brand_alt → Brand Blue/600
  static const Color borderBrandAlt = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Border/border-disabled → Gray (light mode)/300
  static const Color borderDisabled = ZyraColorPrimitives.grayLight300;

  /// Figma: Colors/Border/border-disabled_subtle → Gray (light mode)/200
  static const Color borderDisabledSubtle = ZyraColorPrimitives.grayLight200;

  /// Figma: Colors/Border/border-error → Error/500
  static const Color borderError = ZyraColorPrimitives.error500;

  /// Figma: Colors/Border/border-error_subtle → Error/300
  static const Color borderErrorSubtle = ZyraColorPrimitives.error300;

  /// Figma: Colors/Border/border-inside-reversed-bottom
  static const Color borderInsideReversedBottom = Color(0x33000000);

  /// Figma: Colors/Border/border-inside-reversed-top
  static const Color borderInsideReversedTop = Color(0x00FFFFFF);

  /// Figma: Colors/Border/border-primary → Gray (light mode)/300
  static const Color borderPrimary = ZyraColorPrimitives.grayLight300;

  /// Figma: Colors/Border/border-reversed → Base/white
  static const Color borderReversed = ZyraColorPrimitives.baseWhite;

  /// Figma: Colors/Border/border-secondary → Gray (light mode)/200
  static const Color borderSecondary = ZyraColorPrimitives.grayLight200;

  /// Figma: Colors/Border/border-secondary_alt
  static const Color borderSecondaryAlt = Color(0x0D000000);

  /// Figma: Colors/Border/border-tertiary → Gray (light mode)/100
  static const Color borderTertiary = ZyraColorPrimitives.grayLight100;

  // ===========================================================================
  // Foreground Colors - Figma: Colors/Foreground/*
  // ===========================================================================

  /// Figma: Colors/Foreground/fg-brand-primary (600) → Brand Blue/600
  static const Color fgBrandPrimary = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Foreground/fg-brand-primary_alt → Brand Blue/600
  static const Color fgBrandPrimaryAlt = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Foreground/fg-brand-secondary (500) → Brand Blue/500
  static const Color fgBrandSecondary = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-brand-secondary_alt → Brand Blue/500
  static const Color fgBrandSecondaryAlt = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-brand-secondary_hover → Brand Blue/500
  static const Color fgBrandSecondaryHover = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-disabled → Gray (light mode)/400
  static const Color fgDisabled = ZyraColorPrimitives.grayLight400;

  /// Figma: Colors/Foreground/fg-disabled_subtle → Gray (light mode)/300
  static const Color fgDisabledSubtle = ZyraColorPrimitives.grayLight300;

  /// Figma: Colors/Foreground/fg-error-primary → Error/600
  static const Color fgErrorPrimary = ZyraColorPrimitives.error600;

  /// Figma: Colors/Foreground/fg-error-secondary → Error/500
  static const Color fgErrorSecondary = ZyraColorPrimitives.error500;

  /// Figma: Colors/Foreground/fg-primary (900) → Gray (light mode)/900
  static const Color fgPrimary = ZyraColorPrimitives.grayLight900;

  /// Figma: Colors/Foreground/fg-quaternary (400) → Gray (light mode)/400
  static const Color fgQuaternary = ZyraColorPrimitives.grayLight400;

  /// Figma: Colors/Foreground/fg-quaternary_hover → Gray (light mode)/500
  static const Color fgQuaternaryHover = ZyraColorPrimitives.grayLight500;

  /// Figma: Colors/Foreground/fg-secondary (700) → Gray (light mode)/700
  static const Color fgSecondary = ZyraColorPrimitives.grayLight700;

  /// Figma: Colors/Foreground/fg-secondary_hover → Gray (light mode)/800
  static const Color fgSecondaryHover = ZyraColorPrimitives.grayLight800;

  /// Figma: Colors/Foreground/fg-success-primary → Success/600
  static const Color fgSuccessPrimary = ZyraColorPrimitives.success600;

  /// Figma: Colors/Foreground/fg-success-secondary → Success/500
  static const Color fgSuccessSecondary = ZyraColorPrimitives.success500;

  /// Figma: Colors/Foreground/fg-tertiary (600) → Gray (light mode)/600
  static const Color fgTertiary = ZyraColorPrimitives.grayLight600;

  /// Figma: Colors/Foreground/fg-tertiary_hover → Gray (light mode)/700
  static const Color fgTertiaryHover = ZyraColorPrimitives.grayLight700;

  /// Figma: Colors/Foreground/fg-warning-primary → Warning/600
  static const Color fgWarningPrimary = ZyraColorPrimitives.warning600;

  /// Figma: Colors/Foreground/fg-warning-secondary → Warning/500
  static const Color fgWarningSecondary = ZyraColorPrimitives.warning500;

  /// Figma: Colors/Foreground/fg-white → Base/white
  static const Color fgWhite = ZyraColorPrimitives.baseWhite;

  // ===========================================================================
  // Background Colors - Figma: Colors/Background/*
  // ===========================================================================

  /// Figma: Colors/Background/Black-white-inversed (alpha) → Base/transparent
  static const Color blackWhiteInversed = ZyraColorPrimitives.baseTransparent;

  /// Figma: Colors/Background/bg-active → Gray (light mode)/50
  static const Color bgActive = ZyraColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-brand-primary → Brand Blue/50
  static const Color bgBrandPrimary = ZyraColorPrimitives.brandBlue50;

  /// Figma: Colors/Background/bg-brand-primary_alt → Brand Blue/50
  static const Color bgBrandPrimaryAlt = ZyraColorPrimitives.brandBlue50;

  /// Figma: Colors/Background/bg-brand-secondary → Brand Blue/100
  static const Color bgBrandSecondary = ZyraColorPrimitives.brandBlue100;

  /// Figma: Colors/Background/bg-brand-section → Brand Blue/800
  static const Color bgBrandSection = ZyraColorPrimitives.brandBlue800;

  /// Figma: Colors/Background/bg-brand-section_subtle → Gray (light mode)/100
  static const Color bgBrandSectionSubtle = ZyraColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-brand-solid → Brand Blue/600
  static const Color bgBrandSolid = ZyraColorPrimitives.brandBlue600;

  /// Figma: Colors/Background/bg-brand-solid_hover → Brand Blue/700
  static const Color bgBrandSolidHover = ZyraColorPrimitives.brandBlue700;

  /// Figma: Colors/Background/bg-brand_hover → Gray (light mode alpha)/200
  static const Color bgBrandHover = ZyraColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Background/bg-brand_pressed → Gray (light mode alpha)/300
  static const Color bgBrandPressed = ZyraColorPrimitives.grayLightAlpha300;

  /// Figma: Colors/Background/bg-destructive_hover → Gray (light mode alpha)/200
  static const Color bgDestructiveHover = ZyraColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Background/bg-destructive_pressed → Gray (light mode alpha)/400
  static const Color bgDestructivePressed = ZyraColorPrimitives.grayLightAlpha400;

  /// Figma: Colors/Background/bg-disabled → Gray (light mode)/100
  static const Color bgDisabled = ZyraColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-disabled_subtle → Gray (light mode)/50
  static const Color bgDisabledSubtle = ZyraColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-error-primary → Error/50
  static const Color bgErrorPrimary = ZyraColorPrimitives.error50;

  /// Figma: Colors/Background/bg-error-secondary → Error/100
  static const Color bgErrorSecondary = ZyraColorPrimitives.error100;

  /// Figma: Colors/Background/bg-error-solid → Error/600
  static const Color bgErrorSolid = ZyraColorPrimitives.error600;

  /// Figma: Colors/Background/bg-error-solid_hover → Error/700
  static const Color bgErrorSolidHover = ZyraColorPrimitives.error700;

  /// Figma: Colors/Background/bg-gray_hover → Gray (light mode alpha)/50
  static const Color bgGrayHover = ZyraColorPrimitives.grayLightAlpha50;

  /// Figma: Colors/Background/bg-gray_pressed → Gray (light mode alpha)/200
  static const Color bgGrayPressed = ZyraColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Background/bg-overlay → Gray (light mode)/950
  static const Color bgOverlay = ZyraColorPrimitives.grayLight950;

  /// Figma: Colors/Background/bg-primary → Base/white
  static const Color bgPrimary = ZyraColorPrimitives.baseWhite;

  /// Figma: Colors/Background/bg-primary-solid → Gray (light mode)/950
  static const Color bgPrimarySolid = ZyraColorPrimitives.grayLight950;

  /// Figma: Colors/Background/bg-primary_alt → Base/white
  static const Color bgPrimaryAlt = ZyraColorPrimitives.baseWhite;

  /// Figma: Colors/Background/bg-quaternary → Gray (light mode)/200
  static const Color bgQuaternary = ZyraColorPrimitives.grayLight200;

  /// Figma: Colors/Background/bg-secondary → Gray (light mode)/50
  static const Color bgSecondary = ZyraColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-secondary-solid → Gray (light mode)/600
  static const Color bgSecondarySolid = ZyraColorPrimitives.grayLight600;

  /// Figma: Colors/Background/bg-secondary_alt → Gray (light mode)/50
  static const Color bgSecondaryAlt = ZyraColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-secondary_hover → Gray (light mode)/100
  static const Color bgSecondaryHover = ZyraColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-secondary_subtle → Gray (light mode)/25
  static const Color bgSecondarySubtle = ZyraColorPrimitives.grayLight25;

  /// Figma: Colors/Background/bg-success-primary → Success/50
  static const Color bgSuccessPrimary = ZyraColorPrimitives.success50;

  /// Figma: Colors/Background/bg-success-secondary → Success/100
  static const Color bgSuccessSecondary = ZyraColorPrimitives.success100;

  /// Figma: Colors/Background/bg-success-solid → Success/600
  static const Color bgSuccessSolid = ZyraColorPrimitives.success600;

  /// Figma: Colors/Background/bg-tertiary → Gray (light mode)/100
  static const Color bgTertiary = ZyraColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-warning-primary → Warning/50
  static const Color bgWarningPrimary = ZyraColorPrimitives.warning50;

  /// Figma: Colors/Background/bg-warning-secondary → Warning/100
  static const Color bgWarningSecondary = ZyraColorPrimitives.warning100;

  /// Figma: Colors/Background/bg-warning-solid → Warning/600
  static const Color bgWarningSolid = ZyraColorPrimitives.warning600;

  /// Figma: Colors/Background/bg_destructive_hover_alt → Error/50
  static const Color bgDestructiveHoverAlt = ZyraColorPrimitives.error50;

  /// Figma: Colors/Background/bg_destructive_pressed_alt → Error/200
  static const Color bgDestructivePressedAlt = ZyraColorPrimitives.error200;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/*
  // ===========================================================================

  /// Figma: Colors/Effects/Focus rings/focus-ring → Brand Blue/500
  static const Color focusRing = ZyraColorPrimitives.brandBlue500;

  /// Figma: Colors/Effects/Focus rings/focus-ring-error → Error/500
  static const Color focusRingError = ZyraColorPrimitives.error500;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/Shadows/*
  // ===========================================================================

  /// Figma: Colors/Effects/Shadows/shadow-2xl_01
  static const Color shadow2xl01 = Color(0x2E0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-2xl_02
  static const Color shadow2xl02 = Color(0x0A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-3xl_01
  static const Color shadow3xl01 = Color(0x240A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-3xl_02
  static const Color shadow3xl02 = Color(0x0A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-inversed
  static const Color shadowInversed = Color(0x0AFFFFFF);

  /// Figma: Colors/Effects/Shadows/shadow-lg_01
  static const Color shadowLg01 = Color(0x140A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-lg_02
  static const Color shadowLg02 = Color(0x080A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-lg_03
  static const Color shadowLg03 = Color(0x0A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-md_01
  static const Color shadowMd01 = Color(0x1A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-md_02
  static const Color shadowMd02 = Color(0x0F0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic
  static const Color skeuomorphicShadow = Color(0x0D0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic-inner-border
  static const Color skeuomorphicInnerBorder = Color(0x2E0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-sm_01
  static const Color shadowSm01 = Color(0x1A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-sm_02
  static const Color shadowSm02 = Color(0x1A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-xl_01
  static const Color shadowXl01 = Color(0x140A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-xl_02
  static const Color shadowXl02 = Color(0x080A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-xl_03
  static const Color shadowXl03 = Color(0x0A0A0D12);

  /// Figma: Colors/Effects/Shadows/shadow-xs
  static const Color shadowXs = Color(0x0D0A0D12);

  // ===========================================================================
  // Component Colors - Buttons
  // ===========================================================================

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon → Error/300
  static const Color buttonDestructivePrimaryIcon = ZyraColorPrimitives.error300;

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon_hover → Error/200
  static const Color buttonDestructivePrimaryIconHover = ZyraColorPrimitives.error200;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-background → Gray (light mode alpha)/50
  static const Color buttonGlassPrimaryBackground = ZyraColorPrimitives.grayLightAlpha50;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-hover → Gray (light mode alpha)/100
  static const Color buttonGlassPrimaryHover = ZyraColorPrimitives.grayLightAlpha100;

  /// Figma: Component colors/Components/Buttons/button-primary-icon → Brand Blue/300
  static const Color buttonPrimaryIcon = ZyraColorPrimitives.brandBlue300;

  /// Figma: Component colors/Components/Buttons/button-primary-icon_hover → Brand Blue/200
  static const Color buttonPrimaryIconHover = ZyraColorPrimitives.brandBlue200;

  // ===========================================================================
  // Component Colors - Icons
  // ===========================================================================

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand → Brand Blue/600
  static const Color iconFgBrand = ZyraColorPrimitives.brandBlue600;

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand_on-brand → Brand Blue/200
  static const Color iconFgBrandOnBrand = ZyraColorPrimitives.brandBlue200;

  // ===========================================================================
  // Component Colors - Alpha (mode-invariant)
  // ===========================================================================

  /// Figma: Component colors/Alpha/alpha-black-10
  static const Color alphaBlack10 = Color(0x1A000000);

  /// Figma: Component colors/Alpha/alpha-black-20
  static const Color alphaBlack20 = Color(0x33000000);

  /// Figma: Component colors/Alpha/alpha-black-30
  static const Color alphaBlack30 = Color(0x4D000000);

  /// Figma: Component colors/Alpha/alpha-black-40
  static const Color alphaBlack40 = Color(0x66000000);

  /// Figma: Component colors/Alpha/alpha-black-50
  static const Color alphaBlack50 = Color(0x80000000);

  /// Figma: Component colors/Alpha/alpha-black-60
  static const Color alphaBlack60 = Color(0x99000000);

  /// Figma: Component colors/Alpha/alpha-black-70
  static const Color alphaBlack70 = Color(0xB2000000);

  /// Figma: Component colors/Alpha/alpha-black-80
  static const Color alphaBlack80 = Color(0xCC000000);

  /// Figma: Component colors/Alpha/alpha-black-90
  static const Color alphaBlack90 = Color(0xE5000000);

  /// Figma: Component colors/Alpha/alpha-black-100
  static const Color alphaBlack100 = Color(0xFF000000);

  /// Figma: Component colors/Alpha/alpha-white-10
  static const Color alphaWhite10 = Color(0x1AFFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-20
  static const Color alphaWhite20 = Color(0x33FFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-30
  static const Color alphaWhite30 = Color(0x4DFFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-40
  static const Color alphaWhite40 = Color(0x66FFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-50
  static const Color alphaWhite50 = Color(0x80FFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-60
  static const Color alphaWhite60 = Color(0x99FFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-70
  static const Color alphaWhite70 = Color(0xB2FFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-80
  static const Color alphaWhite80 = Color(0xCCFFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-90
  static const Color alphaWhite90 = Color(0xE5FFFFFF);

  /// Figma: Component colors/Alpha/alpha-white-100
  static const Color alphaWhite100 = Color(0xFFFFFFFF);

  // ===========================================================================
  // Utility Colors
  // ===========================================================================

  /// Figma: Component colors/Utility/Blue/utility-blue-50 → Brand Blue/50
  static const Color utilityBlue50 = ZyraColorPrimitives.brandBlue50;

  /// Figma: Component colors/Utility/Blue/utility-blue-100 → Brand Blue/100
  static const Color utilityBlue100 = ZyraColorPrimitives.brandBlue100;

  /// Figma: Component colors/Utility/Blue/utility-blue-200 → Brand Blue/200
  static const Color utilityBlue200 = ZyraColorPrimitives.brandBlue200;

  /// Figma: Component colors/Utility/Blue/utility-blue-300 → Brand Blue/300
  static const Color utilityBlue300 = ZyraColorPrimitives.brandBlue300;

  /// Figma: Component colors/Utility/Blue/utility-blue-400 → Brand Blue/400
  static const Color utilityBlue400 = ZyraColorPrimitives.brandBlue400;

  /// Figma: Component colors/Utility/Blue/utility-blue-500 → Brand Blue/500
  static const Color utilityBlue500 = ZyraColorPrimitives.brandBlue500;

  /// Figma: Component colors/Utility/Blue/utility-blue-600 → Brand Blue/600
  static const Color utilityBlue600 = ZyraColorPrimitives.brandBlue600;

  /// Figma: Component colors/Utility/Blue/utility-blue-700 → Brand Blue/700
  static const Color utilityBlue700 = ZyraColorPrimitives.brandBlue700;

  /// Figma: Component colors/Utility/Error/utility-error-50 → Error/50
  static const Color utilityError50 = ZyraColorPrimitives.error50;

  /// Figma: Component colors/Utility/Error/utility-error-100 → Error/100
  static const Color utilityError100 = ZyraColorPrimitives.error100;

  /// Figma: Component colors/Utility/Error/utility-error-200 → Error/200
  static const Color utilityError200 = ZyraColorPrimitives.error200;

  /// Figma: Component colors/Utility/Error/utility-error-300 → Error/300
  static const Color utilityError300 = ZyraColorPrimitives.error300;

  /// Figma: Component colors/Utility/Error/utility-error-400 → Error/400
  static const Color utilityError400 = ZyraColorPrimitives.error400;

  /// Figma: Component colors/Utility/Error/utility-error-500 → Error/500
  static const Color utilityError500 = ZyraColorPrimitives.error500;

  /// Figma: Component colors/Utility/Error/utility-error-600 → Error/600
  static const Color utilityError600 = ZyraColorPrimitives.error600;

  /// Figma: Component colors/Utility/Error/utility-error-700 → Error/700
  static const Color utilityError700 = ZyraColorPrimitives.error700;

  /// Figma: Component colors/Utility/Success/utility-success-50 → Success/50
  static const Color utilitySuccess50 = ZyraColorPrimitives.success50;

  /// Figma: Component colors/Utility/Success/utility-success-100 → Success/100
  static const Color utilitySuccess100 = ZyraColorPrimitives.success100;

  /// Figma: Component colors/Utility/Success/utility-success-200 → Success/200
  static const Color utilitySuccess200 = ZyraColorPrimitives.success200;

  /// Figma: Component colors/Utility/Success/utility-success-300 → Success/300
  static const Color utilitySuccess300 = ZyraColorPrimitives.success300;

  /// Figma: Component colors/Utility/Success/utility-success-400 → Success/400
  static const Color utilitySuccess400 = ZyraColorPrimitives.success400;

  /// Figma: Component colors/Utility/Success/utility-success-500 → Success/500
  static const Color utilitySuccess500 = ZyraColorPrimitives.success500;

  /// Figma: Component colors/Utility/Success/utility-success-600 → Success/600
  static const Color utilitySuccess600 = ZyraColorPrimitives.success600;

  /// Figma: Component colors/Utility/Success/utility-success-700 → Success/700
  static const Color utilitySuccess700 = ZyraColorPrimitives.success700;

  /// Figma: Component colors/Utility/Warning/utility-warning-50 → Warning/50
  static const Color utilityWarning50 = ZyraColorPrimitives.warning50;

  /// Figma: Component colors/Utility/Warning/utility-warning-100 → Warning/100
  static const Color utilityWarning100 = ZyraColorPrimitives.warning100;

  /// Figma: Component colors/Utility/Warning/utility-warning-200 → Warning/200
  static const Color utilityWarning200 = ZyraColorPrimitives.warning200;

  /// Figma: Component colors/Utility/Warning/utility-warning-300 → Warning/300
  static const Color utilityWarning300 = ZyraColorPrimitives.warning300;

  /// Figma: Component colors/Utility/Warning/utility-warning-400 → Warning/400
  static const Color utilityWarning400 = ZyraColorPrimitives.warning400;

  /// Figma: Component colors/Utility/Warning/utility-warning-500 → Warning/500
  static const Color utilityWarning500 = ZyraColorPrimitives.warning500;

  /// Figma: Component colors/Utility/Warning/utility-warning-600 → Warning/600
  static const Color utilityWarning600 = ZyraColorPrimitives.warning600;

  /// Figma: Component colors/Utility/Warning/utility-warning-700 → Warning/700
  static const Color utilityWarning700 = ZyraColorPrimitives.warning700;

  // ===========================================================================
  // Other
  // ===========================================================================

  /// Figma: Component colors/Components/Avatars/avatar-styles-bg-neutral
  static const Color avatarStylesBgNeutral = Color(0xFFE0E0E0);

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-brand → Brand Blue/600
  static const Color featuredIconLightFgBrand = ZyraColorPrimitives.brandBlue600;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-error → Error/600
  static const Color featuredIconLightFgError = ZyraColorPrimitives.error600;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-gray → Gray (light mode)/500
  static const Color featuredIconLightFgGray = ZyraColorPrimitives.grayLight500;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-success → Success/600
  static const Color featuredIconLightFgSuccess = ZyraColorPrimitives.success600;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-warning → Warning/600
  static const Color featuredIconLightFgWarning = ZyraColorPrimitives.warning600;

  /// Figma: Component colors/Components/Icons/Main Avatar/gradient-bottom → Brand Blue/700
  static const Color gradientBottom = ZyraColorPrimitives.brandBlue700;

  /// Figma: Component colors/Components/Icons/Main Avatar/gradient-top → Brand Blue/400
  static const Color gradientTop = ZyraColorPrimitives.brandBlue400;

  /// Figma: Component colors/Components/Toggles/toggle-border → Gray (light mode)/300
  static const Color toggleBorder = ZyraColorPrimitives.grayLight300;

  /// Figma: Component colors/Components/Toggles/toggle-button-fg_disabled → Gray (light mode)/50
  static const Color toggleButtonFgDisabled = ZyraColorPrimitives.grayLight50;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed → Background/bg-brand-solid
  static const Color toggleSlimBorderPressed = ZyraColorsLight.bgBrandSolid;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed-hover → Background/bg-brand-solid_hover
  static const Color toggleSlimBorderPressedHover = ZyraColorsLight.bgBrandSolidHover;
}

/// Semantic color tokens that adapt to light/dark mode.
///
/// Maps directly to Figma "Color modes" variables.
/// Property names follow Figma naming: `text-primary` → `textPrimary`.
///
/// Usage via `context.zyra`:
/// ```dart
/// Container(
///   color: context.zyra.colors.bgPrimary,
///   child: Text(
///     'Hello',
///     style: TextStyle(color: context.zyra.colors.textPrimary),
///   ),
/// )
/// ```
@immutable
// ignore: use_enums, theme token containers need class semantics and static dark/light singletons
final class ZyraColors {
  // ===========================================================================
  // Dark Mode - Figma: Color mode = Dark
  // ===========================================================================

  static const dark = ZyraColors._(
    brightness: Brightness.dark,
    // Text
    textBrandPrimary: ZyraColorsDark.textBrandPrimary,
    textBrandSecondary: ZyraColorsDark.textBrandSecondary,
    textBrandSecondaryHover: ZyraColorsDark.textBrandSecondaryHover,
    textBrandTertiary: ZyraColorsDark.textBrandTertiary,
    textBrandTertiaryAlt: ZyraColorsDark.textBrandTertiaryAlt,
    textDisabled: ZyraColorsDark.textDisabled,
    textErrorPrimary: ZyraColorsDark.textErrorPrimary,
    textErrorPrimaryHover: ZyraColorsDark.textErrorPrimaryHover,
    textPlaceholder: ZyraColorsDark.textPlaceholder,
    textPlaceholderSubtle: ZyraColorsDark.textPlaceholderSubtle,
    textPrimary: ZyraColorsDark.textPrimary,
    textPrimaryOnBrand: ZyraColorsDark.textPrimaryOnBrand,
    textPrimaryOnWhite: ZyraColorsDark.textPrimaryOnWhite,
    textQuaternary: ZyraColorsDark.textQuaternary,
    textQuaternaryOnBrand: ZyraColorsDark.textQuaternaryOnBrand,
    textSecondary: ZyraColorsDark.textSecondary,
    textSecondaryHover: ZyraColorsDark.textSecondaryHover,
    textSecondaryOnBrand: ZyraColorsDark.textSecondaryOnBrand,
    textSuccessPrimary: ZyraColorsDark.textSuccessPrimary,
    textTertiary: ZyraColorsDark.textTertiary,
    textTertiaryHover: ZyraColorsDark.textTertiaryHover,
    textTertiaryOnBrand: ZyraColorsDark.textTertiaryOnBrand,
    textWarningPrimary: ZyraColorsDark.textWarningPrimary,
    textWhite: ZyraColorsDark.textWhite,
    // Border
    borderBrand: ZyraColorsDark.borderBrand,
    borderBrandAlt: ZyraColorsDark.borderBrandAlt,
    borderDisabled: ZyraColorsDark.borderDisabled,
    borderDisabledSubtle: ZyraColorsDark.borderDisabledSubtle,
    borderError: ZyraColorsDark.borderError,
    borderErrorSubtle: ZyraColorsDark.borderErrorSubtle,
    borderInsideReversedBottom: ZyraColorsDark.borderInsideReversedBottom,
    borderInsideReversedTop: ZyraColorsDark.borderInsideReversedTop,
    borderPrimary: ZyraColorsDark.borderPrimary,
    borderReversed: ZyraColorsDark.borderReversed,
    borderSecondary: ZyraColorsDark.borderSecondary,
    borderSecondaryAlt: ZyraColorsDark.borderSecondaryAlt,
    borderTertiary: ZyraColorsDark.borderTertiary,
    // Foreground
    fgBrandPrimary: ZyraColorsDark.fgBrandPrimary,
    fgBrandPrimaryAlt: ZyraColorsDark.fgBrandPrimaryAlt,
    fgBrandSecondary: ZyraColorsDark.fgBrandSecondary,
    fgBrandSecondaryAlt: ZyraColorsDark.fgBrandSecondaryAlt,
    fgBrandSecondaryHover: ZyraColorsDark.fgBrandSecondaryHover,
    fgDisabled: ZyraColorsDark.fgDisabled,
    fgDisabledSubtle: ZyraColorsDark.fgDisabledSubtle,
    fgErrorPrimary: ZyraColorsDark.fgErrorPrimary,
    fgErrorSecondary: ZyraColorsDark.fgErrorSecondary,
    fgPrimary: ZyraColorsDark.fgPrimary,
    fgQuaternary: ZyraColorsDark.fgQuaternary,
    fgQuaternaryHover: ZyraColorsDark.fgQuaternaryHover,
    fgSecondary: ZyraColorsDark.fgSecondary,
    fgSecondaryHover: ZyraColorsDark.fgSecondaryHover,
    fgSuccessPrimary: ZyraColorsDark.fgSuccessPrimary,
    fgSuccessSecondary: ZyraColorsDark.fgSuccessSecondary,
    fgTertiary: ZyraColorsDark.fgTertiary,
    fgTertiaryHover: ZyraColorsDark.fgTertiaryHover,
    fgWarningPrimary: ZyraColorsDark.fgWarningPrimary,
    fgWarningSecondary: ZyraColorsDark.fgWarningSecondary,
    fgWhite: ZyraColorsDark.fgWhite,
    // Background
    blackWhiteInversed: ZyraColorsDark.blackWhiteInversed,
    bgActive: ZyraColorsDark.bgActive,
    bgBrandPrimary: ZyraColorsDark.bgBrandPrimary,
    bgBrandPrimaryAlt: ZyraColorsDark.bgBrandPrimaryAlt,
    bgBrandSecondary: ZyraColorsDark.bgBrandSecondary,
    bgBrandSection: ZyraColorsDark.bgBrandSection,
    bgBrandSectionSubtle: ZyraColorsDark.bgBrandSectionSubtle,
    bgBrandSolid: ZyraColorsDark.bgBrandSolid,
    bgBrandSolidHover: ZyraColorsDark.bgBrandSolidHover,
    bgBrandHover: ZyraColorsDark.bgBrandHover,
    bgBrandPressed: ZyraColorsDark.bgBrandPressed,
    bgDestructiveHover: ZyraColorsDark.bgDestructiveHover,
    bgDestructivePressed: ZyraColorsDark.bgDestructivePressed,
    bgDisabled: ZyraColorsDark.bgDisabled,
    bgDisabledSubtle: ZyraColorsDark.bgDisabledSubtle,
    bgErrorPrimary: ZyraColorsDark.bgErrorPrimary,
    bgErrorSecondary: ZyraColorsDark.bgErrorSecondary,
    bgErrorSolid: ZyraColorsDark.bgErrorSolid,
    bgErrorSolidHover: ZyraColorsDark.bgErrorSolidHover,
    bgGrayHover: ZyraColorsDark.bgGrayHover,
    bgGrayPressed: ZyraColorsDark.bgGrayPressed,
    bgOverlay: ZyraColorsDark.bgOverlay,
    bgPrimary: ZyraColorsDark.bgPrimary,
    bgPrimarySolid: ZyraColorsDark.bgPrimarySolid,
    bgPrimaryAlt: ZyraColorsDark.bgPrimaryAlt,
    bgQuaternary: ZyraColorsDark.bgQuaternary,
    bgSecondary: ZyraColorsDark.bgSecondary,
    bgSecondarySolid: ZyraColorsDark.bgSecondarySolid,
    bgSecondaryAlt: ZyraColorsDark.bgSecondaryAlt,
    bgSecondaryHover: ZyraColorsDark.bgSecondaryHover,
    bgSecondarySubtle: ZyraColorsDark.bgSecondarySubtle,
    bgSuccessPrimary: ZyraColorsDark.bgSuccessPrimary,
    bgSuccessSecondary: ZyraColorsDark.bgSuccessSecondary,
    bgSuccessSolid: ZyraColorsDark.bgSuccessSolid,
    bgTertiary: ZyraColorsDark.bgTertiary,
    bgWarningPrimary: ZyraColorsDark.bgWarningPrimary,
    bgWarningSecondary: ZyraColorsDark.bgWarningSecondary,
    bgWarningSolid: ZyraColorsDark.bgWarningSolid,
    bgDestructiveHoverAlt: ZyraColorsDark.bgDestructiveHoverAlt,
    bgDestructivePressedAlt: ZyraColorsDark.bgDestructivePressedAlt,
    // Effects
    focusRing: ZyraColorsDark.focusRing,
    focusRingError: ZyraColorsDark.focusRingError,
    // Shadows
    shadow2xl01: ZyraColorsDark.shadow2xl01,
    shadow2xl02: ZyraColorsDark.shadow2xl02,
    shadow3xl01: ZyraColorsDark.shadow3xl01,
    shadow3xl02: ZyraColorsDark.shadow3xl02,
    shadowInversed: ZyraColorsDark.shadowInversed,
    shadowLg01: ZyraColorsDark.shadowLg01,
    shadowLg02: ZyraColorsDark.shadowLg02,
    shadowLg03: ZyraColorsDark.shadowLg03,
    shadowMd01: ZyraColorsDark.shadowMd01,
    shadowMd02: ZyraColorsDark.shadowMd02,
    skeuomorphicShadow: ZyraColorsDark.skeuomorphicShadow,
    skeuomorphicInnerBorder: ZyraColorsDark.skeuomorphicInnerBorder,
    shadowSm01: ZyraColorsDark.shadowSm01,
    shadowSm02: ZyraColorsDark.shadowSm02,
    shadowXl01: ZyraColorsDark.shadowXl01,
    shadowXl02: ZyraColorsDark.shadowXl02,
    shadowXl03: ZyraColorsDark.shadowXl03,
    shadowXs: ZyraColorsDark.shadowXs,
    // Buttons
    buttonDestructivePrimaryIcon: ZyraColorsDark.buttonDestructivePrimaryIcon,
    buttonDestructivePrimaryIconHover: ZyraColorsDark.buttonDestructivePrimaryIconHover,
    buttonGlassPrimaryBackground: ZyraColorsDark.buttonGlassPrimaryBackground,
    buttonGlassPrimaryHover: ZyraColorsDark.buttonGlassPrimaryHover,
    buttonPrimaryIcon: ZyraColorsDark.buttonPrimaryIcon,
    buttonPrimaryIconHover: ZyraColorsDark.buttonPrimaryIconHover,
    // Icons
    iconFgBrand: ZyraColorsDark.iconFgBrand,
    iconFgBrandOnBrand: ZyraColorsDark.iconFgBrandOnBrand,
    // Alpha
    alphaBlack10: ZyraColorsDark.alphaBlack10,
    alphaBlack20: ZyraColorsDark.alphaBlack20,
    alphaBlack30: ZyraColorsDark.alphaBlack30,
    alphaBlack40: ZyraColorsDark.alphaBlack40,
    alphaBlack50: ZyraColorsDark.alphaBlack50,
    alphaBlack60: ZyraColorsDark.alphaBlack60,
    alphaBlack70: ZyraColorsDark.alphaBlack70,
    alphaBlack80: ZyraColorsDark.alphaBlack80,
    alphaBlack90: ZyraColorsDark.alphaBlack90,
    alphaBlack100: ZyraColorsDark.alphaBlack100,
    alphaWhite10: ZyraColorsDark.alphaWhite10,
    alphaWhite20: ZyraColorsDark.alphaWhite20,
    alphaWhite30: ZyraColorsDark.alphaWhite30,
    alphaWhite40: ZyraColorsDark.alphaWhite40,
    alphaWhite50: ZyraColorsDark.alphaWhite50,
    alphaWhite60: ZyraColorsDark.alphaWhite60,
    alphaWhite70: ZyraColorsDark.alphaWhite70,
    alphaWhite80: ZyraColorsDark.alphaWhite80,
    alphaWhite90: ZyraColorsDark.alphaWhite90,
    alphaWhite100: ZyraColorsDark.alphaWhite100,
    // Utility
    utilityBlue50: ZyraColorsDark.utilityBlue50,
    utilityBlue100: ZyraColorsDark.utilityBlue100,
    utilityBlue200: ZyraColorsDark.utilityBlue200,
    utilityBlue300: ZyraColorsDark.utilityBlue300,
    utilityBlue400: ZyraColorsDark.utilityBlue400,
    utilityBlue500: ZyraColorsDark.utilityBlue500,
    utilityBlue600: ZyraColorsDark.utilityBlue600,
    utilityBlue700: ZyraColorsDark.utilityBlue700,
    utilityError50: ZyraColorsDark.utilityError50,
    utilityError100: ZyraColorsDark.utilityError100,
    utilityError200: ZyraColorsDark.utilityError200,
    utilityError300: ZyraColorsDark.utilityError300,
    utilityError400: ZyraColorsDark.utilityError400,
    utilityError500: ZyraColorsDark.utilityError500,
    utilityError600: ZyraColorsDark.utilityError600,
    utilityError700: ZyraColorsDark.utilityError700,
    utilitySuccess50: ZyraColorsDark.utilitySuccess50,
    utilitySuccess100: ZyraColorsDark.utilitySuccess100,
    utilitySuccess200: ZyraColorsDark.utilitySuccess200,
    utilitySuccess300: ZyraColorsDark.utilitySuccess300,
    utilitySuccess400: ZyraColorsDark.utilitySuccess400,
    utilitySuccess500: ZyraColorsDark.utilitySuccess500,
    utilitySuccess600: ZyraColorsDark.utilitySuccess600,
    utilitySuccess700: ZyraColorsDark.utilitySuccess700,
    utilityWarning50: ZyraColorsDark.utilityWarning50,
    utilityWarning100: ZyraColorsDark.utilityWarning100,
    utilityWarning200: ZyraColorsDark.utilityWarning200,
    utilityWarning300: ZyraColorsDark.utilityWarning300,
    utilityWarning400: ZyraColorsDark.utilityWarning400,
    utilityWarning500: ZyraColorsDark.utilityWarning500,
    utilityWarning600: ZyraColorsDark.utilityWarning600,
    utilityWarning700: ZyraColorsDark.utilityWarning700,
    // Other
    avatarStylesBgNeutral: ZyraColorsDark.avatarStylesBgNeutral,
    featuredIconLightFgBrand: ZyraColorsDark.featuredIconLightFgBrand,
    featuredIconLightFgError: ZyraColorsDark.featuredIconLightFgError,
    featuredIconLightFgGray: ZyraColorsDark.featuredIconLightFgGray,
    featuredIconLightFgSuccess: ZyraColorsDark.featuredIconLightFgSuccess,
    featuredIconLightFgWarning: ZyraColorsDark.featuredIconLightFgWarning,
    gradientBottom: ZyraColorsDark.gradientBottom,
    gradientTop: ZyraColorsDark.gradientTop,
    toggleBorder: ZyraColorsDark.toggleBorder,
    toggleButtonFgDisabled: ZyraColorsDark.toggleButtonFgDisabled,
    toggleSlimBorderPressed: ZyraColorsDark.toggleSlimBorderPressed,
    toggleSlimBorderPressedHover: ZyraColorsDark.toggleSlimBorderPressedHover,
  );

  const ZyraColors._({
    required this.brightness,
    // Text
    required this.textBrandPrimary,
    required this.textBrandSecondary,
    required this.textBrandSecondaryHover,
    required this.textBrandTertiary,
    required this.textBrandTertiaryAlt,
    required this.textDisabled,
    required this.textErrorPrimary,
    required this.textErrorPrimaryHover,
    required this.textPlaceholder,
    required this.textPlaceholderSubtle,
    required this.textPrimary,
    required this.textPrimaryOnBrand,
    required this.textPrimaryOnWhite,
    required this.textQuaternary,
    required this.textQuaternaryOnBrand,
    required this.textSecondary,
    required this.textSecondaryHover,
    required this.textSecondaryOnBrand,
    required this.textSuccessPrimary,
    required this.textTertiary,
    required this.textTertiaryHover,
    required this.textTertiaryOnBrand,
    required this.textWarningPrimary,
    required this.textWhite,
    // Border
    required this.borderBrand,
    required this.borderBrandAlt,
    required this.borderDisabled,
    required this.borderDisabledSubtle,
    required this.borderError,
    required this.borderErrorSubtle,
    required this.borderInsideReversedBottom,
    required this.borderInsideReversedTop,
    required this.borderPrimary,
    required this.borderReversed,
    required this.borderSecondary,
    required this.borderSecondaryAlt,
    required this.borderTertiary,
    // Foreground
    required this.fgBrandPrimary,
    required this.fgBrandPrimaryAlt,
    required this.fgBrandSecondary,
    required this.fgBrandSecondaryAlt,
    required this.fgBrandSecondaryHover,
    required this.fgDisabled,
    required this.fgDisabledSubtle,
    required this.fgErrorPrimary,
    required this.fgErrorSecondary,
    required this.fgPrimary,
    required this.fgQuaternary,
    required this.fgQuaternaryHover,
    required this.fgSecondary,
    required this.fgSecondaryHover,
    required this.fgSuccessPrimary,
    required this.fgSuccessSecondary,
    required this.fgTertiary,
    required this.fgTertiaryHover,
    required this.fgWarningPrimary,
    required this.fgWarningSecondary,
    required this.fgWhite,
    // Background
    required this.blackWhiteInversed,
    required this.bgActive,
    required this.bgBrandPrimary,
    required this.bgBrandPrimaryAlt,
    required this.bgBrandSecondary,
    required this.bgBrandSection,
    required this.bgBrandSectionSubtle,
    required this.bgBrandSolid,
    required this.bgBrandSolidHover,
    required this.bgBrandHover,
    required this.bgBrandPressed,
    required this.bgDestructiveHover,
    required this.bgDestructivePressed,
    required this.bgDisabled,
    required this.bgDisabledSubtle,
    required this.bgErrorPrimary,
    required this.bgErrorSecondary,
    required this.bgErrorSolid,
    required this.bgErrorSolidHover,
    required this.bgGrayHover,
    required this.bgGrayPressed,
    required this.bgOverlay,
    required this.bgPrimary,
    required this.bgPrimarySolid,
    required this.bgPrimaryAlt,
    required this.bgQuaternary,
    required this.bgSecondary,
    required this.bgSecondarySolid,
    required this.bgSecondaryAlt,
    required this.bgSecondaryHover,
    required this.bgSecondarySubtle,
    required this.bgSuccessPrimary,
    required this.bgSuccessSecondary,
    required this.bgSuccessSolid,
    required this.bgTertiary,
    required this.bgWarningPrimary,
    required this.bgWarningSecondary,
    required this.bgWarningSolid,
    required this.bgDestructiveHoverAlt,
    required this.bgDestructivePressedAlt,
    // Effects
    required this.focusRing,
    required this.focusRingError,
    // Shadows
    required this.shadow2xl01,
    required this.shadow2xl02,
    required this.shadow3xl01,
    required this.shadow3xl02,
    required this.shadowInversed,
    required this.shadowLg01,
    required this.shadowLg02,
    required this.shadowLg03,
    required this.shadowMd01,
    required this.shadowMd02,
    required this.skeuomorphicShadow,
    required this.skeuomorphicInnerBorder,
    required this.shadowSm01,
    required this.shadowSm02,
    required this.shadowXl01,
    required this.shadowXl02,
    required this.shadowXl03,
    required this.shadowXs,
    // Buttons
    required this.buttonDestructivePrimaryIcon,
    required this.buttonDestructivePrimaryIconHover,
    required this.buttonGlassPrimaryBackground,
    required this.buttonGlassPrimaryHover,
    required this.buttonPrimaryIcon,
    required this.buttonPrimaryIconHover,
    // Icons
    required this.iconFgBrand,
    required this.iconFgBrandOnBrand,
    // Alpha
    required this.alphaBlack10,
    required this.alphaBlack20,
    required this.alphaBlack30,
    required this.alphaBlack40,
    required this.alphaBlack50,
    required this.alphaBlack60,
    required this.alphaBlack70,
    required this.alphaBlack80,
    required this.alphaBlack90,
    required this.alphaBlack100,
    required this.alphaWhite10,
    required this.alphaWhite20,
    required this.alphaWhite30,
    required this.alphaWhite40,
    required this.alphaWhite50,
    required this.alphaWhite60,
    required this.alphaWhite70,
    required this.alphaWhite80,
    required this.alphaWhite90,
    required this.alphaWhite100,
    // Utility
    required this.utilityBlue50,
    required this.utilityBlue100,
    required this.utilityBlue200,
    required this.utilityBlue300,
    required this.utilityBlue400,
    required this.utilityBlue500,
    required this.utilityBlue600,
    required this.utilityBlue700,
    required this.utilityError50,
    required this.utilityError100,
    required this.utilityError200,
    required this.utilityError300,
    required this.utilityError400,
    required this.utilityError500,
    required this.utilityError600,
    required this.utilityError700,
    required this.utilitySuccess50,
    required this.utilitySuccess100,
    required this.utilitySuccess200,
    required this.utilitySuccess300,
    required this.utilitySuccess400,
    required this.utilitySuccess500,
    required this.utilitySuccess600,
    required this.utilitySuccess700,
    required this.utilityWarning50,
    required this.utilityWarning100,
    required this.utilityWarning200,
    required this.utilityWarning300,
    required this.utilityWarning400,
    required this.utilityWarning500,
    required this.utilityWarning600,
    required this.utilityWarning700,
    // Other
    required this.avatarStylesBgNeutral,
    required this.featuredIconLightFgBrand,
    required this.featuredIconLightFgError,
    required this.featuredIconLightFgGray,
    required this.featuredIconLightFgSuccess,
    required this.featuredIconLightFgWarning,
    required this.gradientBottom,
    required this.gradientTop,
    required this.toggleBorder,
    required this.toggleButtonFgDisabled,
    required this.toggleSlimBorderPressed,
    required this.toggleSlimBorderPressedHover,
  });

  /// Whether this color set is for [Brightness.light] or [Brightness.dark] mode.
  final Brightness brightness;

  // ===========================================================================
  // Text Colors - Figma: Colors/Text/*
  // ===========================================================================

  /// Figma: Colors/Text/text-brand-primary (900)
  final Color textBrandPrimary;

  /// Figma: Colors/Text/text-brand-secondary (700)
  final Color textBrandSecondary;

  /// Figma: Colors/Text/text-brand-secondary_hover
  final Color textBrandSecondaryHover;

  /// Figma: Colors/Text/text-brand-tertiary (600)
  final Color textBrandTertiary;

  /// Figma: Colors/Text/text-brand-tertiary_alt
  final Color textBrandTertiaryAlt;

  /// Figma: Colors/Text/text-disabled
  final Color textDisabled;

  /// Figma: Colors/Text/text-error-primary (600)
  final Color textErrorPrimary;

  /// Figma: Colors/Text/text-error-primary_hover
  final Color textErrorPrimaryHover;

  /// Figma: Colors/Text/text-placeholder
  final Color textPlaceholder;

  /// Figma: Colors/Text/text-placeholder_subtle
  final Color textPlaceholderSubtle;

  /// Figma: Colors/Text/text-primary (900)
  final Color textPrimary;

  /// Figma: Colors/Text/text-primary_on-brand
  final Color textPrimaryOnBrand;

  /// Figma: Colors/Text/text-primary_on-white
  final Color textPrimaryOnWhite;

  /// Figma: Colors/Text/text-quaternary (500)
  final Color textQuaternary;

  /// Figma: Colors/Text/text-quaternary_on-brand
  final Color textQuaternaryOnBrand;

  /// Figma: Colors/Text/text-secondary (600)
  final Color textSecondary;

  /// Figma: Colors/Text/text-secondary_hover
  final Color textSecondaryHover;

  /// Figma: Colors/Text/text-secondary_on-brand
  final Color textSecondaryOnBrand;

  /// Figma: Colors/Text/text-success-primary (600)
  final Color textSuccessPrimary;

  /// Figma: Colors/Text/text-tertiary (600)
  final Color textTertiary;

  /// Figma: Colors/Text/text-tertiary_hover
  final Color textTertiaryHover;

  /// Figma: Colors/Text/text-tertiary_on-brand
  final Color textTertiaryOnBrand;

  /// Figma: Colors/Text/text-warning-primary (600)
  final Color textWarningPrimary;

  /// Figma: Colors/Text/text-white
  final Color textWhite;

  // ===========================================================================
  // Border Colors - Figma: Colors/Border/*
  // ===========================================================================

  /// Figma: Colors/Border/border-brand
  final Color borderBrand;

  /// Figma: Colors/Border/border-brand_alt
  final Color borderBrandAlt;

  /// Figma: Colors/Border/border-disabled
  final Color borderDisabled;

  /// Figma: Colors/Border/border-disabled_subtle
  final Color borderDisabledSubtle;

  /// Figma: Colors/Border/border-error
  final Color borderError;

  /// Figma: Colors/Border/border-error_subtle
  final Color borderErrorSubtle;

  /// Figma: Colors/Border/border-inside-reversed-bottom
  final Color borderInsideReversedBottom;

  /// Figma: Colors/Border/border-inside-reversed-top
  final Color borderInsideReversedTop;

  /// Figma: Colors/Border/border-primary
  final Color borderPrimary;

  /// Figma: Colors/Border/border-reversed
  final Color borderReversed;

  /// Figma: Colors/Border/border-secondary
  final Color borderSecondary;

  /// Figma: Colors/Border/border-secondary_alt
  final Color borderSecondaryAlt;

  /// Figma: Colors/Border/border-tertiary
  final Color borderTertiary;

  // ===========================================================================
  // Foreground Colors - Figma: Colors/Foreground/*
  // ===========================================================================

  /// Figma: Colors/Foreground/fg-brand-primary (600)
  final Color fgBrandPrimary;

  /// Figma: Colors/Foreground/fg-brand-primary_alt
  final Color fgBrandPrimaryAlt;

  /// Figma: Colors/Foreground/fg-brand-secondary (500)
  final Color fgBrandSecondary;

  /// Figma: Colors/Foreground/fg-brand-secondary_alt
  final Color fgBrandSecondaryAlt;

  /// Figma: Colors/Foreground/fg-brand-secondary_hover
  final Color fgBrandSecondaryHover;

  /// Figma: Colors/Foreground/fg-disabled
  final Color fgDisabled;

  /// Figma: Colors/Foreground/fg-disabled_subtle
  final Color fgDisabledSubtle;

  /// Figma: Colors/Foreground/fg-error-primary
  final Color fgErrorPrimary;

  /// Figma: Colors/Foreground/fg-error-secondary
  final Color fgErrorSecondary;

  /// Figma: Colors/Foreground/fg-primary (900)
  final Color fgPrimary;

  /// Figma: Colors/Foreground/fg-quaternary (400)
  final Color fgQuaternary;

  /// Figma: Colors/Foreground/fg-quaternary_hover
  final Color fgQuaternaryHover;

  /// Figma: Colors/Foreground/fg-secondary (700)
  final Color fgSecondary;

  /// Figma: Colors/Foreground/fg-secondary_hover
  final Color fgSecondaryHover;

  /// Figma: Colors/Foreground/fg-success-primary
  final Color fgSuccessPrimary;

  /// Figma: Colors/Foreground/fg-success-secondary
  final Color fgSuccessSecondary;

  /// Figma: Colors/Foreground/fg-tertiary (600)
  final Color fgTertiary;

  /// Figma: Colors/Foreground/fg-tertiary_hover
  final Color fgTertiaryHover;

  /// Figma: Colors/Foreground/fg-warning-primary
  final Color fgWarningPrimary;

  /// Figma: Colors/Foreground/fg-warning-secondary
  final Color fgWarningSecondary;

  /// Figma: Colors/Foreground/fg-white
  final Color fgWhite;

  // ===========================================================================
  // Background Colors - Figma: Colors/Background/*
  // ===========================================================================

  /// Figma: Colors/Background/Black-white-inversed (alpha)
  final Color blackWhiteInversed;

  /// Figma: Colors/Background/bg-active
  final Color bgActive;

  /// Figma: Colors/Background/bg-brand-primary
  final Color bgBrandPrimary;

  /// Figma: Colors/Background/bg-brand-primary_alt
  final Color bgBrandPrimaryAlt;

  /// Figma: Colors/Background/bg-brand-secondary
  final Color bgBrandSecondary;

  /// Figma: Colors/Background/bg-brand-section
  final Color bgBrandSection;

  /// Figma: Colors/Background/bg-brand-section_subtle
  final Color bgBrandSectionSubtle;

  /// Figma: Colors/Background/bg-brand-solid
  final Color bgBrandSolid;

  /// Figma: Colors/Background/bg-brand-solid_hover
  final Color bgBrandSolidHover;

  /// Figma: Colors/Background/bg-brand_hover
  final Color bgBrandHover;

  /// Figma: Colors/Background/bg-brand_pressed
  final Color bgBrandPressed;

  /// Figma: Colors/Background/bg-destructive_hover
  final Color bgDestructiveHover;

  /// Figma: Colors/Background/bg-destructive_pressed
  final Color bgDestructivePressed;

  /// Figma: Colors/Background/bg-disabled
  final Color bgDisabled;

  /// Figma: Colors/Background/bg-disabled_subtle
  final Color bgDisabledSubtle;

  /// Figma: Colors/Background/bg-error-primary
  final Color bgErrorPrimary;

  /// Figma: Colors/Background/bg-error-secondary
  final Color bgErrorSecondary;

  /// Figma: Colors/Background/bg-error-solid
  final Color bgErrorSolid;

  /// Figma: Colors/Background/bg-error-solid_hover
  final Color bgErrorSolidHover;

  /// Figma: Colors/Background/bg-gray_hover
  final Color bgGrayHover;

  /// Figma: Colors/Background/bg-gray_pressed
  final Color bgGrayPressed;

  /// Figma: Colors/Background/bg-overlay
  final Color bgOverlay;

  /// Figma: Colors/Background/bg-primary
  final Color bgPrimary;

  /// Figma: Colors/Background/bg-primary-solid
  final Color bgPrimarySolid;

  /// Figma: Colors/Background/bg-primary_alt
  final Color bgPrimaryAlt;

  /// Figma: Colors/Background/bg-quaternary
  final Color bgQuaternary;

  /// Figma: Colors/Background/bg-secondary
  final Color bgSecondary;

  /// Figma: Colors/Background/bg-secondary-solid
  final Color bgSecondarySolid;

  /// Figma: Colors/Background/bg-secondary_alt
  final Color bgSecondaryAlt;

  /// Figma: Colors/Background/bg-secondary_hover
  final Color bgSecondaryHover;

  /// Figma: Colors/Background/bg-secondary_subtle
  final Color bgSecondarySubtle;

  /// Figma: Colors/Background/bg-success-primary
  final Color bgSuccessPrimary;

  /// Figma: Colors/Background/bg-success-secondary
  final Color bgSuccessSecondary;

  /// Figma: Colors/Background/bg-success-solid
  final Color bgSuccessSolid;

  /// Figma: Colors/Background/bg-tertiary
  final Color bgTertiary;

  /// Figma: Colors/Background/bg-warning-primary
  final Color bgWarningPrimary;

  /// Figma: Colors/Background/bg-warning-secondary
  final Color bgWarningSecondary;

  /// Figma: Colors/Background/bg-warning-solid
  final Color bgWarningSolid;

  /// Figma: Colors/Background/bg_destructive_hover_alt
  final Color bgDestructiveHoverAlt;

  /// Figma: Colors/Background/bg_destructive_pressed_alt
  final Color bgDestructivePressedAlt;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/*
  // ===========================================================================

  /// Figma: Colors/Effects/Focus rings/focus-ring
  final Color focusRing;

  /// Figma: Colors/Effects/Focus rings/focus-ring-error
  final Color focusRingError;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/Shadows/*
  // ===========================================================================

  /// Figma: Colors/Effects/Shadows/shadow-2xl_01
  final Color shadow2xl01;

  /// Figma: Colors/Effects/Shadows/shadow-2xl_02
  final Color shadow2xl02;

  /// Figma: Colors/Effects/Shadows/shadow-3xl_01
  final Color shadow3xl01;

  /// Figma: Colors/Effects/Shadows/shadow-3xl_02
  final Color shadow3xl02;

  /// Figma: Colors/Effects/Shadows/shadow-inversed
  final Color shadowInversed;

  /// Figma: Colors/Effects/Shadows/shadow-lg_01
  final Color shadowLg01;

  /// Figma: Colors/Effects/Shadows/shadow-lg_02
  final Color shadowLg02;

  /// Figma: Colors/Effects/Shadows/shadow-lg_03
  final Color shadowLg03;

  /// Figma: Colors/Effects/Shadows/shadow-md_01
  final Color shadowMd01;

  /// Figma: Colors/Effects/Shadows/shadow-md_02
  final Color shadowMd02;

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic
  final Color skeuomorphicShadow;

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic-inner-border
  final Color skeuomorphicInnerBorder;

  /// Figma: Colors/Effects/Shadows/shadow-sm_01
  final Color shadowSm01;

  /// Figma: Colors/Effects/Shadows/shadow-sm_02
  final Color shadowSm02;

  /// Figma: Colors/Effects/Shadows/shadow-xl_01
  final Color shadowXl01;

  /// Figma: Colors/Effects/Shadows/shadow-xl_02
  final Color shadowXl02;

  /// Figma: Colors/Effects/Shadows/shadow-xl_03
  final Color shadowXl03;

  /// Figma: Colors/Effects/Shadows/shadow-xs
  final Color shadowXs;

  // ===========================================================================
  // Component Colors - Buttons
  // ===========================================================================

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon
  final Color buttonDestructivePrimaryIcon;

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon_hover
  final Color buttonDestructivePrimaryIconHover;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-background
  final Color buttonGlassPrimaryBackground;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-hover
  final Color buttonGlassPrimaryHover;

  /// Figma: Component colors/Components/Buttons/button-primary-icon
  final Color buttonPrimaryIcon;

  /// Figma: Component colors/Components/Buttons/button-primary-icon_hover
  final Color buttonPrimaryIconHover;

  // ===========================================================================
  // Component Colors - Icons
  // ===========================================================================

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand
  final Color iconFgBrand;

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand_on-brand
  final Color iconFgBrandOnBrand;

  // ===========================================================================
  // Component Colors - Alpha (mode-invariant)
  // ===========================================================================

  /// Figma: Component colors/Alpha/alpha-black-10
  final Color alphaBlack10;

  /// Figma: Component colors/Alpha/alpha-black-20
  final Color alphaBlack20;

  /// Figma: Component colors/Alpha/alpha-black-30
  final Color alphaBlack30;

  /// Figma: Component colors/Alpha/alpha-black-40
  final Color alphaBlack40;

  /// Figma: Component colors/Alpha/alpha-black-50
  final Color alphaBlack50;

  /// Figma: Component colors/Alpha/alpha-black-60
  final Color alphaBlack60;

  /// Figma: Component colors/Alpha/alpha-black-70
  final Color alphaBlack70;

  /// Figma: Component colors/Alpha/alpha-black-80
  final Color alphaBlack80;

  /// Figma: Component colors/Alpha/alpha-black-90
  final Color alphaBlack90;

  /// Figma: Component colors/Alpha/alpha-black-100
  final Color alphaBlack100;

  /// Figma: Component colors/Alpha/alpha-white-10
  final Color alphaWhite10;

  /// Figma: Component colors/Alpha/alpha-white-20
  final Color alphaWhite20;

  /// Figma: Component colors/Alpha/alpha-white-30
  final Color alphaWhite30;

  /// Figma: Component colors/Alpha/alpha-white-40
  final Color alphaWhite40;

  /// Figma: Component colors/Alpha/alpha-white-50
  final Color alphaWhite50;

  /// Figma: Component colors/Alpha/alpha-white-60
  final Color alphaWhite60;

  /// Figma: Component colors/Alpha/alpha-white-70
  final Color alphaWhite70;

  /// Figma: Component colors/Alpha/alpha-white-80
  final Color alphaWhite80;

  /// Figma: Component colors/Alpha/alpha-white-90
  final Color alphaWhite90;

  /// Figma: Component colors/Alpha/alpha-white-100
  final Color alphaWhite100;

  // ===========================================================================
  // Utility Colors
  // ===========================================================================

  /// Figma: Component colors/Utility/Blue/utility-blue-50
  final Color utilityBlue50;

  /// Figma: Component colors/Utility/Blue/utility-blue-100
  final Color utilityBlue100;

  /// Figma: Component colors/Utility/Blue/utility-blue-200
  final Color utilityBlue200;

  /// Figma: Component colors/Utility/Blue/utility-blue-300
  final Color utilityBlue300;

  /// Figma: Component colors/Utility/Blue/utility-blue-400
  final Color utilityBlue400;

  /// Figma: Component colors/Utility/Blue/utility-blue-500
  final Color utilityBlue500;

  /// Figma: Component colors/Utility/Blue/utility-blue-600
  final Color utilityBlue600;

  /// Figma: Component colors/Utility/Blue/utility-blue-700
  final Color utilityBlue700;

  /// Figma: Component colors/Utility/Error/utility-error-50
  final Color utilityError50;

  /// Figma: Component colors/Utility/Error/utility-error-100
  final Color utilityError100;

  /// Figma: Component colors/Utility/Error/utility-error-200
  final Color utilityError200;

  /// Figma: Component colors/Utility/Error/utility-error-300
  final Color utilityError300;

  /// Figma: Component colors/Utility/Error/utility-error-400
  final Color utilityError400;

  /// Figma: Component colors/Utility/Error/utility-error-500
  final Color utilityError500;

  /// Figma: Component colors/Utility/Error/utility-error-600
  final Color utilityError600;

  /// Figma: Component colors/Utility/Error/utility-error-700
  final Color utilityError700;

  /// Figma: Component colors/Utility/Success/utility-success-50
  final Color utilitySuccess50;

  /// Figma: Component colors/Utility/Success/utility-success-100
  final Color utilitySuccess100;

  /// Figma: Component colors/Utility/Success/utility-success-200
  final Color utilitySuccess200;

  /// Figma: Component colors/Utility/Success/utility-success-300
  final Color utilitySuccess300;

  /// Figma: Component colors/Utility/Success/utility-success-400
  final Color utilitySuccess400;

  /// Figma: Component colors/Utility/Success/utility-success-500
  final Color utilitySuccess500;

  /// Figma: Component colors/Utility/Success/utility-success-600
  final Color utilitySuccess600;

  /// Figma: Component colors/Utility/Success/utility-success-700
  final Color utilitySuccess700;

  /// Figma: Component colors/Utility/Warning/utility-warning-50
  final Color utilityWarning50;

  /// Figma: Component colors/Utility/Warning/utility-warning-100
  final Color utilityWarning100;

  /// Figma: Component colors/Utility/Warning/utility-warning-200
  final Color utilityWarning200;

  /// Figma: Component colors/Utility/Warning/utility-warning-300
  final Color utilityWarning300;

  /// Figma: Component colors/Utility/Warning/utility-warning-400
  final Color utilityWarning400;

  /// Figma: Component colors/Utility/Warning/utility-warning-500
  final Color utilityWarning500;

  /// Figma: Component colors/Utility/Warning/utility-warning-600
  final Color utilityWarning600;

  /// Figma: Component colors/Utility/Warning/utility-warning-700
  final Color utilityWarning700;

  // ===========================================================================
  // Other
  // ===========================================================================

  /// Figma: Component colors/Components/Avatars/avatar-styles-bg-neutral
  final Color avatarStylesBgNeutral;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-brand
  final Color featuredIconLightFgBrand;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-error
  final Color featuredIconLightFgError;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-gray
  final Color featuredIconLightFgGray;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-success
  final Color featuredIconLightFgSuccess;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-warning
  final Color featuredIconLightFgWarning;

  /// Figma: Component colors/Components/Icons/Main Avatar/gradient-bottom
  final Color gradientBottom;

  /// Figma: Component colors/Components/Icons/Main Avatar/gradient-top
  final Color gradientTop;

  /// Figma: Component colors/Components/Toggles/toggle-border
  final Color toggleBorder;

  /// Figma: Component colors/Components/Toggles/toggle-button-fg_disabled
  final Color toggleButtonFgDisabled;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed
  final Color toggleSlimBorderPressed;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed-hover
  final Color toggleSlimBorderPressedHover;

  // ===========================================================================
  // Light Mode - Figma: Color mode = Light
  // ===========================================================================

  static const light = ZyraColors._(
    brightness: Brightness.light,
    // Text
    textBrandPrimary: ZyraColorsLight.textBrandPrimary,
    textBrandSecondary: ZyraColorsLight.textBrandSecondary,
    textBrandSecondaryHover: ZyraColorsLight.textBrandSecondaryHover,
    textBrandTertiary: ZyraColorsLight.textBrandTertiary,
    textBrandTertiaryAlt: ZyraColorsLight.textBrandTertiaryAlt,
    textDisabled: ZyraColorsLight.textDisabled,
    textErrorPrimary: ZyraColorsLight.textErrorPrimary,
    textErrorPrimaryHover: ZyraColorsLight.textErrorPrimaryHover,
    textPlaceholder: ZyraColorsLight.textPlaceholder,
    textPlaceholderSubtle: ZyraColorsLight.textPlaceholderSubtle,
    textPrimary: ZyraColorsLight.textPrimary,
    textPrimaryOnBrand: ZyraColorsLight.textPrimaryOnBrand,
    textPrimaryOnWhite: ZyraColorsLight.textPrimaryOnWhite,
    textQuaternary: ZyraColorsLight.textQuaternary,
    textQuaternaryOnBrand: ZyraColorsLight.textQuaternaryOnBrand,
    textSecondary: ZyraColorsLight.textSecondary,
    textSecondaryHover: ZyraColorsLight.textSecondaryHover,
    textSecondaryOnBrand: ZyraColorsLight.textSecondaryOnBrand,
    textSuccessPrimary: ZyraColorsLight.textSuccessPrimary,
    textTertiary: ZyraColorsLight.textTertiary,
    textTertiaryHover: ZyraColorsLight.textTertiaryHover,
    textTertiaryOnBrand: ZyraColorsLight.textTertiaryOnBrand,
    textWarningPrimary: ZyraColorsLight.textWarningPrimary,
    textWhite: ZyraColorsLight.textWhite,
    // Border
    borderBrand: ZyraColorsLight.borderBrand,
    borderBrandAlt: ZyraColorsLight.borderBrandAlt,
    borderDisabled: ZyraColorsLight.borderDisabled,
    borderDisabledSubtle: ZyraColorsLight.borderDisabledSubtle,
    borderError: ZyraColorsLight.borderError,
    borderErrorSubtle: ZyraColorsLight.borderErrorSubtle,
    borderInsideReversedBottom: ZyraColorsLight.borderInsideReversedBottom,
    borderInsideReversedTop: ZyraColorsLight.borderInsideReversedTop,
    borderPrimary: ZyraColorsLight.borderPrimary,
    borderReversed: ZyraColorsLight.borderReversed,
    borderSecondary: ZyraColorsLight.borderSecondary,
    borderSecondaryAlt: ZyraColorsLight.borderSecondaryAlt,
    borderTertiary: ZyraColorsLight.borderTertiary,
    // Foreground
    fgBrandPrimary: ZyraColorsLight.fgBrandPrimary,
    fgBrandPrimaryAlt: ZyraColorsLight.fgBrandPrimaryAlt,
    fgBrandSecondary: ZyraColorsLight.fgBrandSecondary,
    fgBrandSecondaryAlt: ZyraColorsLight.fgBrandSecondaryAlt,
    fgBrandSecondaryHover: ZyraColorsLight.fgBrandSecondaryHover,
    fgDisabled: ZyraColorsLight.fgDisabled,
    fgDisabledSubtle: ZyraColorsLight.fgDisabledSubtle,
    fgErrorPrimary: ZyraColorsLight.fgErrorPrimary,
    fgErrorSecondary: ZyraColorsLight.fgErrorSecondary,
    fgPrimary: ZyraColorsLight.fgPrimary,
    fgQuaternary: ZyraColorsLight.fgQuaternary,
    fgQuaternaryHover: ZyraColorsLight.fgQuaternaryHover,
    fgSecondary: ZyraColorsLight.fgSecondary,
    fgSecondaryHover: ZyraColorsLight.fgSecondaryHover,
    fgSuccessPrimary: ZyraColorsLight.fgSuccessPrimary,
    fgSuccessSecondary: ZyraColorsLight.fgSuccessSecondary,
    fgTertiary: ZyraColorsLight.fgTertiary,
    fgTertiaryHover: ZyraColorsLight.fgTertiaryHover,
    fgWarningPrimary: ZyraColorsLight.fgWarningPrimary,
    fgWarningSecondary: ZyraColorsLight.fgWarningSecondary,
    fgWhite: ZyraColorsLight.fgWhite,
    // Background
    blackWhiteInversed: ZyraColorsLight.blackWhiteInversed,
    bgActive: ZyraColorsLight.bgActive,
    bgBrandPrimary: ZyraColorsLight.bgBrandPrimary,
    bgBrandPrimaryAlt: ZyraColorsLight.bgBrandPrimaryAlt,
    bgBrandSecondary: ZyraColorsLight.bgBrandSecondary,
    bgBrandSection: ZyraColorsLight.bgBrandSection,
    bgBrandSectionSubtle: ZyraColorsLight.bgBrandSectionSubtle,
    bgBrandSolid: ZyraColorsLight.bgBrandSolid,
    bgBrandSolidHover: ZyraColorsLight.bgBrandSolidHover,
    bgBrandHover: ZyraColorsLight.bgBrandHover,
    bgBrandPressed: ZyraColorsLight.bgBrandPressed,
    bgDestructiveHover: ZyraColorsLight.bgDestructiveHover,
    bgDestructivePressed: ZyraColorsLight.bgDestructivePressed,
    bgDisabled: ZyraColorsLight.bgDisabled,
    bgDisabledSubtle: ZyraColorsLight.bgDisabledSubtle,
    bgErrorPrimary: ZyraColorsLight.bgErrorPrimary,
    bgErrorSecondary: ZyraColorsLight.bgErrorSecondary,
    bgErrorSolid: ZyraColorsLight.bgErrorSolid,
    bgErrorSolidHover: ZyraColorsLight.bgErrorSolidHover,
    bgGrayHover: ZyraColorsLight.bgGrayHover,
    bgGrayPressed: ZyraColorsLight.bgGrayPressed,
    bgOverlay: ZyraColorsLight.bgOverlay,
    bgPrimary: ZyraColorsLight.bgPrimary,
    bgPrimarySolid: ZyraColorsLight.bgPrimarySolid,
    bgPrimaryAlt: ZyraColorsLight.bgPrimaryAlt,
    bgQuaternary: ZyraColorsLight.bgQuaternary,
    bgSecondary: ZyraColorsLight.bgSecondary,
    bgSecondarySolid: ZyraColorsLight.bgSecondarySolid,
    bgSecondaryAlt: ZyraColorsLight.bgSecondaryAlt,
    bgSecondaryHover: ZyraColorsLight.bgSecondaryHover,
    bgSecondarySubtle: ZyraColorsLight.bgSecondarySubtle,
    bgSuccessPrimary: ZyraColorsLight.bgSuccessPrimary,
    bgSuccessSecondary: ZyraColorsLight.bgSuccessSecondary,
    bgSuccessSolid: ZyraColorsLight.bgSuccessSolid,
    bgTertiary: ZyraColorsLight.bgTertiary,
    bgWarningPrimary: ZyraColorsLight.bgWarningPrimary,
    bgWarningSecondary: ZyraColorsLight.bgWarningSecondary,
    bgWarningSolid: ZyraColorsLight.bgWarningSolid,
    bgDestructiveHoverAlt: ZyraColorsLight.bgDestructiveHoverAlt,
    bgDestructivePressedAlt: ZyraColorsLight.bgDestructivePressedAlt,
    // Effects
    focusRing: ZyraColorsLight.focusRing,
    focusRingError: ZyraColorsLight.focusRingError,
    // Shadows
    shadow2xl01: ZyraColorsLight.shadow2xl01,
    shadow2xl02: ZyraColorsLight.shadow2xl02,
    shadow3xl01: ZyraColorsLight.shadow3xl01,
    shadow3xl02: ZyraColorsLight.shadow3xl02,
    shadowInversed: ZyraColorsLight.shadowInversed,
    shadowLg01: ZyraColorsLight.shadowLg01,
    shadowLg02: ZyraColorsLight.shadowLg02,
    shadowLg03: ZyraColorsLight.shadowLg03,
    shadowMd01: ZyraColorsLight.shadowMd01,
    shadowMd02: ZyraColorsLight.shadowMd02,
    skeuomorphicShadow: ZyraColorsLight.skeuomorphicShadow,
    skeuomorphicInnerBorder: ZyraColorsLight.skeuomorphicInnerBorder,
    shadowSm01: ZyraColorsLight.shadowSm01,
    shadowSm02: ZyraColorsLight.shadowSm02,
    shadowXl01: ZyraColorsLight.shadowXl01,
    shadowXl02: ZyraColorsLight.shadowXl02,
    shadowXl03: ZyraColorsLight.shadowXl03,
    shadowXs: ZyraColorsLight.shadowXs,
    // Buttons
    buttonDestructivePrimaryIcon: ZyraColorsLight.buttonDestructivePrimaryIcon,
    buttonDestructivePrimaryIconHover: ZyraColorsLight.buttonDestructivePrimaryIconHover,
    buttonGlassPrimaryBackground: ZyraColorsLight.buttonGlassPrimaryBackground,
    buttonGlassPrimaryHover: ZyraColorsLight.buttonGlassPrimaryHover,
    buttonPrimaryIcon: ZyraColorsLight.buttonPrimaryIcon,
    buttonPrimaryIconHover: ZyraColorsLight.buttonPrimaryIconHover,
    // Icons
    iconFgBrand: ZyraColorsLight.iconFgBrand,
    iconFgBrandOnBrand: ZyraColorsLight.iconFgBrandOnBrand,
    // Alpha
    alphaBlack10: ZyraColorsLight.alphaBlack10,
    alphaBlack20: ZyraColorsLight.alphaBlack20,
    alphaBlack30: ZyraColorsLight.alphaBlack30,
    alphaBlack40: ZyraColorsLight.alphaBlack40,
    alphaBlack50: ZyraColorsLight.alphaBlack50,
    alphaBlack60: ZyraColorsLight.alphaBlack60,
    alphaBlack70: ZyraColorsLight.alphaBlack70,
    alphaBlack80: ZyraColorsLight.alphaBlack80,
    alphaBlack90: ZyraColorsLight.alphaBlack90,
    alphaBlack100: ZyraColorsLight.alphaBlack100,
    alphaWhite10: ZyraColorsLight.alphaWhite10,
    alphaWhite20: ZyraColorsLight.alphaWhite20,
    alphaWhite30: ZyraColorsLight.alphaWhite30,
    alphaWhite40: ZyraColorsLight.alphaWhite40,
    alphaWhite50: ZyraColorsLight.alphaWhite50,
    alphaWhite60: ZyraColorsLight.alphaWhite60,
    alphaWhite70: ZyraColorsLight.alphaWhite70,
    alphaWhite80: ZyraColorsLight.alphaWhite80,
    alphaWhite90: ZyraColorsLight.alphaWhite90,
    alphaWhite100: ZyraColorsLight.alphaWhite100,
    // Utility
    utilityBlue50: ZyraColorsLight.utilityBlue50,
    utilityBlue100: ZyraColorsLight.utilityBlue100,
    utilityBlue200: ZyraColorsLight.utilityBlue200,
    utilityBlue300: ZyraColorsLight.utilityBlue300,
    utilityBlue400: ZyraColorsLight.utilityBlue400,
    utilityBlue500: ZyraColorsLight.utilityBlue500,
    utilityBlue600: ZyraColorsLight.utilityBlue600,
    utilityBlue700: ZyraColorsLight.utilityBlue700,
    utilityError50: ZyraColorsLight.utilityError50,
    utilityError100: ZyraColorsLight.utilityError100,
    utilityError200: ZyraColorsLight.utilityError200,
    utilityError300: ZyraColorsLight.utilityError300,
    utilityError400: ZyraColorsLight.utilityError400,
    utilityError500: ZyraColorsLight.utilityError500,
    utilityError600: ZyraColorsLight.utilityError600,
    utilityError700: ZyraColorsLight.utilityError700,
    utilitySuccess50: ZyraColorsLight.utilitySuccess50,
    utilitySuccess100: ZyraColorsLight.utilitySuccess100,
    utilitySuccess200: ZyraColorsLight.utilitySuccess200,
    utilitySuccess300: ZyraColorsLight.utilitySuccess300,
    utilitySuccess400: ZyraColorsLight.utilitySuccess400,
    utilitySuccess500: ZyraColorsLight.utilitySuccess500,
    utilitySuccess600: ZyraColorsLight.utilitySuccess600,
    utilitySuccess700: ZyraColorsLight.utilitySuccess700,
    utilityWarning50: ZyraColorsLight.utilityWarning50,
    utilityWarning100: ZyraColorsLight.utilityWarning100,
    utilityWarning200: ZyraColorsLight.utilityWarning200,
    utilityWarning300: ZyraColorsLight.utilityWarning300,
    utilityWarning400: ZyraColorsLight.utilityWarning400,
    utilityWarning500: ZyraColorsLight.utilityWarning500,
    utilityWarning600: ZyraColorsLight.utilityWarning600,
    utilityWarning700: ZyraColorsLight.utilityWarning700,
    // Other
    avatarStylesBgNeutral: ZyraColorsLight.avatarStylesBgNeutral,
    featuredIconLightFgBrand: ZyraColorsLight.featuredIconLightFgBrand,
    featuredIconLightFgError: ZyraColorsLight.featuredIconLightFgError,
    featuredIconLightFgGray: ZyraColorsLight.featuredIconLightFgGray,
    featuredIconLightFgSuccess: ZyraColorsLight.featuredIconLightFgSuccess,
    featuredIconLightFgWarning: ZyraColorsLight.featuredIconLightFgWarning,
    gradientBottom: ZyraColorsLight.gradientBottom,
    gradientTop: ZyraColorsLight.gradientTop,
    toggleBorder: ZyraColorsLight.toggleBorder,
    toggleButtonFgDisabled: ZyraColorsLight.toggleButtonFgDisabled,
    toggleSlimBorderPressed: ZyraColorsLight.toggleSlimBorderPressed,
    toggleSlimBorderPressedHover: ZyraColorsLight.toggleSlimBorderPressedHover,
  );

  static ZyraColors lerpColors({required ZyraColors a, required ZyraColors b, required double t}) => ZyraColors._(
    brightness: t < 0.5 ? a.brightness : b.brightness,
    // Text
    textBrandPrimary: lerpColorNonNull(a.textBrandPrimary, b.textBrandPrimary, t),
    textBrandSecondary: lerpColorNonNull(a.textBrandSecondary, b.textBrandSecondary, t),
    textBrandSecondaryHover: lerpColorNonNull(a.textBrandSecondaryHover, b.textBrandSecondaryHover, t),
    textBrandTertiary: lerpColorNonNull(a.textBrandTertiary, b.textBrandTertiary, t),
    textBrandTertiaryAlt: lerpColorNonNull(a.textBrandTertiaryAlt, b.textBrandTertiaryAlt, t),
    textDisabled: lerpColorNonNull(a.textDisabled, b.textDisabled, t),
    textErrorPrimary: lerpColorNonNull(a.textErrorPrimary, b.textErrorPrimary, t),
    textErrorPrimaryHover: lerpColorNonNull(a.textErrorPrimaryHover, b.textErrorPrimaryHover, t),
    textPlaceholder: lerpColorNonNull(a.textPlaceholder, b.textPlaceholder, t),
    textPlaceholderSubtle: lerpColorNonNull(a.textPlaceholderSubtle, b.textPlaceholderSubtle, t),
    textPrimary: lerpColorNonNull(a.textPrimary, b.textPrimary, t),
    textPrimaryOnBrand: lerpColorNonNull(a.textPrimaryOnBrand, b.textPrimaryOnBrand, t),
    textPrimaryOnWhite: lerpColorNonNull(a.textPrimaryOnWhite, b.textPrimaryOnWhite, t),
    textQuaternary: lerpColorNonNull(a.textQuaternary, b.textQuaternary, t),
    textQuaternaryOnBrand: lerpColorNonNull(a.textQuaternaryOnBrand, b.textQuaternaryOnBrand, t),
    textSecondary: lerpColorNonNull(a.textSecondary, b.textSecondary, t),
    textSecondaryHover: lerpColorNonNull(a.textSecondaryHover, b.textSecondaryHover, t),
    textSecondaryOnBrand: lerpColorNonNull(a.textSecondaryOnBrand, b.textSecondaryOnBrand, t),
    textSuccessPrimary: lerpColorNonNull(a.textSuccessPrimary, b.textSuccessPrimary, t),
    textTertiary: lerpColorNonNull(a.textTertiary, b.textTertiary, t),
    textTertiaryHover: lerpColorNonNull(a.textTertiaryHover, b.textTertiaryHover, t),
    textTertiaryOnBrand: lerpColorNonNull(a.textTertiaryOnBrand, b.textTertiaryOnBrand, t),
    textWarningPrimary: lerpColorNonNull(a.textWarningPrimary, b.textWarningPrimary, t),
    textWhite: lerpColorNonNull(a.textWhite, b.textWhite, t),
    // Border
    borderBrand: lerpColorNonNull(a.borderBrand, b.borderBrand, t),
    borderBrandAlt: lerpColorNonNull(a.borderBrandAlt, b.borderBrandAlt, t),
    borderDisabled: lerpColorNonNull(a.borderDisabled, b.borderDisabled, t),
    borderDisabledSubtle: lerpColorNonNull(a.borderDisabledSubtle, b.borderDisabledSubtle, t),
    borderError: lerpColorNonNull(a.borderError, b.borderError, t),
    borderErrorSubtle: lerpColorNonNull(a.borderErrorSubtle, b.borderErrorSubtle, t),
    borderInsideReversedBottom: lerpColorNonNull(a.borderInsideReversedBottom, b.borderInsideReversedBottom, t),
    borderInsideReversedTop: lerpColorNonNull(a.borderInsideReversedTop, b.borderInsideReversedTop, t),
    borderPrimary: lerpColorNonNull(a.borderPrimary, b.borderPrimary, t),
    borderReversed: lerpColorNonNull(a.borderReversed, b.borderReversed, t),
    borderSecondary: lerpColorNonNull(a.borderSecondary, b.borderSecondary, t),
    borderSecondaryAlt: lerpColorNonNull(a.borderSecondaryAlt, b.borderSecondaryAlt, t),
    borderTertiary: lerpColorNonNull(a.borderTertiary, b.borderTertiary, t),
    // Foreground
    fgBrandPrimary: lerpColorNonNull(a.fgBrandPrimary, b.fgBrandPrimary, t),
    fgBrandPrimaryAlt: lerpColorNonNull(a.fgBrandPrimaryAlt, b.fgBrandPrimaryAlt, t),
    fgBrandSecondary: lerpColorNonNull(a.fgBrandSecondary, b.fgBrandSecondary, t),
    fgBrandSecondaryAlt: lerpColorNonNull(a.fgBrandSecondaryAlt, b.fgBrandSecondaryAlt, t),
    fgBrandSecondaryHover: lerpColorNonNull(a.fgBrandSecondaryHover, b.fgBrandSecondaryHover, t),
    fgDisabled: lerpColorNonNull(a.fgDisabled, b.fgDisabled, t),
    fgDisabledSubtle: lerpColorNonNull(a.fgDisabledSubtle, b.fgDisabledSubtle, t),
    fgErrorPrimary: lerpColorNonNull(a.fgErrorPrimary, b.fgErrorPrimary, t),
    fgErrorSecondary: lerpColorNonNull(a.fgErrorSecondary, b.fgErrorSecondary, t),
    fgPrimary: lerpColorNonNull(a.fgPrimary, b.fgPrimary, t),
    fgQuaternary: lerpColorNonNull(a.fgQuaternary, b.fgQuaternary, t),
    fgQuaternaryHover: lerpColorNonNull(a.fgQuaternaryHover, b.fgQuaternaryHover, t),
    fgSecondary: lerpColorNonNull(a.fgSecondary, b.fgSecondary, t),
    fgSecondaryHover: lerpColorNonNull(a.fgSecondaryHover, b.fgSecondaryHover, t),
    fgSuccessPrimary: lerpColorNonNull(a.fgSuccessPrimary, b.fgSuccessPrimary, t),
    fgSuccessSecondary: lerpColorNonNull(a.fgSuccessSecondary, b.fgSuccessSecondary, t),
    fgTertiary: lerpColorNonNull(a.fgTertiary, b.fgTertiary, t),
    fgTertiaryHover: lerpColorNonNull(a.fgTertiaryHover, b.fgTertiaryHover, t),
    fgWarningPrimary: lerpColorNonNull(a.fgWarningPrimary, b.fgWarningPrimary, t),
    fgWarningSecondary: lerpColorNonNull(a.fgWarningSecondary, b.fgWarningSecondary, t),
    fgWhite: lerpColorNonNull(a.fgWhite, b.fgWhite, t),
    // Background
    blackWhiteInversed: lerpColorNonNull(a.blackWhiteInversed, b.blackWhiteInversed, t),
    bgActive: lerpColorNonNull(a.bgActive, b.bgActive, t),
    bgBrandPrimary: lerpColorNonNull(a.bgBrandPrimary, b.bgBrandPrimary, t),
    bgBrandPrimaryAlt: lerpColorNonNull(a.bgBrandPrimaryAlt, b.bgBrandPrimaryAlt, t),
    bgBrandSecondary: lerpColorNonNull(a.bgBrandSecondary, b.bgBrandSecondary, t),
    bgBrandSection: lerpColorNonNull(a.bgBrandSection, b.bgBrandSection, t),
    bgBrandSectionSubtle: lerpColorNonNull(a.bgBrandSectionSubtle, b.bgBrandSectionSubtle, t),
    bgBrandSolid: lerpColorNonNull(a.bgBrandSolid, b.bgBrandSolid, t),
    bgBrandSolidHover: lerpColorNonNull(a.bgBrandSolidHover, b.bgBrandSolidHover, t),
    bgBrandHover: lerpColorNonNull(a.bgBrandHover, b.bgBrandHover, t),
    bgBrandPressed: lerpColorNonNull(a.bgBrandPressed, b.bgBrandPressed, t),
    bgDestructiveHover: lerpColorNonNull(a.bgDestructiveHover, b.bgDestructiveHover, t),
    bgDestructivePressed: lerpColorNonNull(a.bgDestructivePressed, b.bgDestructivePressed, t),
    bgDisabled: lerpColorNonNull(a.bgDisabled, b.bgDisabled, t),
    bgDisabledSubtle: lerpColorNonNull(a.bgDisabledSubtle, b.bgDisabledSubtle, t),
    bgErrorPrimary: lerpColorNonNull(a.bgErrorPrimary, b.bgErrorPrimary, t),
    bgErrorSecondary: lerpColorNonNull(a.bgErrorSecondary, b.bgErrorSecondary, t),
    bgErrorSolid: lerpColorNonNull(a.bgErrorSolid, b.bgErrorSolid, t),
    bgErrorSolidHover: lerpColorNonNull(a.bgErrorSolidHover, b.bgErrorSolidHover, t),
    bgGrayHover: lerpColorNonNull(a.bgGrayHover, b.bgGrayHover, t),
    bgGrayPressed: lerpColorNonNull(a.bgGrayPressed, b.bgGrayPressed, t),
    bgOverlay: lerpColorNonNull(a.bgOverlay, b.bgOverlay, t),
    bgPrimary: lerpColorNonNull(a.bgPrimary, b.bgPrimary, t),
    bgPrimarySolid: lerpColorNonNull(a.bgPrimarySolid, b.bgPrimarySolid, t),
    bgPrimaryAlt: lerpColorNonNull(a.bgPrimaryAlt, b.bgPrimaryAlt, t),
    bgQuaternary: lerpColorNonNull(a.bgQuaternary, b.bgQuaternary, t),
    bgSecondary: lerpColorNonNull(a.bgSecondary, b.bgSecondary, t),
    bgSecondarySolid: lerpColorNonNull(a.bgSecondarySolid, b.bgSecondarySolid, t),
    bgSecondaryAlt: lerpColorNonNull(a.bgSecondaryAlt, b.bgSecondaryAlt, t),
    bgSecondaryHover: lerpColorNonNull(a.bgSecondaryHover, b.bgSecondaryHover, t),
    bgSecondarySubtle: lerpColorNonNull(a.bgSecondarySubtle, b.bgSecondarySubtle, t),
    bgSuccessPrimary: lerpColorNonNull(a.bgSuccessPrimary, b.bgSuccessPrimary, t),
    bgSuccessSecondary: lerpColorNonNull(a.bgSuccessSecondary, b.bgSuccessSecondary, t),
    bgSuccessSolid: lerpColorNonNull(a.bgSuccessSolid, b.bgSuccessSolid, t),
    bgTertiary: lerpColorNonNull(a.bgTertiary, b.bgTertiary, t),
    bgWarningPrimary: lerpColorNonNull(a.bgWarningPrimary, b.bgWarningPrimary, t),
    bgWarningSecondary: lerpColorNonNull(a.bgWarningSecondary, b.bgWarningSecondary, t),
    bgWarningSolid: lerpColorNonNull(a.bgWarningSolid, b.bgWarningSolid, t),
    bgDestructiveHoverAlt: lerpColorNonNull(a.bgDestructiveHoverAlt, b.bgDestructiveHoverAlt, t),
    bgDestructivePressedAlt: lerpColorNonNull(a.bgDestructivePressedAlt, b.bgDestructivePressedAlt, t),
    // Effects
    focusRing: lerpColorNonNull(a.focusRing, b.focusRing, t),
    focusRingError: lerpColorNonNull(a.focusRingError, b.focusRingError, t),
    // Shadows
    shadow2xl01: lerpColorNonNull(a.shadow2xl01, b.shadow2xl01, t),
    shadow2xl02: lerpColorNonNull(a.shadow2xl02, b.shadow2xl02, t),
    shadow3xl01: lerpColorNonNull(a.shadow3xl01, b.shadow3xl01, t),
    shadow3xl02: lerpColorNonNull(a.shadow3xl02, b.shadow3xl02, t),
    shadowInversed: lerpColorNonNull(a.shadowInversed, b.shadowInversed, t),
    shadowLg01: lerpColorNonNull(a.shadowLg01, b.shadowLg01, t),
    shadowLg02: lerpColorNonNull(a.shadowLg02, b.shadowLg02, t),
    shadowLg03: lerpColorNonNull(a.shadowLg03, b.shadowLg03, t),
    shadowMd01: lerpColorNonNull(a.shadowMd01, b.shadowMd01, t),
    shadowMd02: lerpColorNonNull(a.shadowMd02, b.shadowMd02, t),
    skeuomorphicShadow: lerpColorNonNull(a.skeuomorphicShadow, b.skeuomorphicShadow, t),
    skeuomorphicInnerBorder: lerpColorNonNull(a.skeuomorphicInnerBorder, b.skeuomorphicInnerBorder, t),
    shadowSm01: lerpColorNonNull(a.shadowSm01, b.shadowSm01, t),
    shadowSm02: lerpColorNonNull(a.shadowSm02, b.shadowSm02, t),
    shadowXl01: lerpColorNonNull(a.shadowXl01, b.shadowXl01, t),
    shadowXl02: lerpColorNonNull(a.shadowXl02, b.shadowXl02, t),
    shadowXl03: lerpColorNonNull(a.shadowXl03, b.shadowXl03, t),
    shadowXs: lerpColorNonNull(a.shadowXs, b.shadowXs, t),
    // Buttons
    buttonDestructivePrimaryIcon: lerpColorNonNull(a.buttonDestructivePrimaryIcon, b.buttonDestructivePrimaryIcon, t),
    buttonDestructivePrimaryIconHover: lerpColorNonNull(a.buttonDestructivePrimaryIconHover, b.buttonDestructivePrimaryIconHover, t),
    buttonGlassPrimaryBackground: lerpColorNonNull(a.buttonGlassPrimaryBackground, b.buttonGlassPrimaryBackground, t),
    buttonGlassPrimaryHover: lerpColorNonNull(a.buttonGlassPrimaryHover, b.buttonGlassPrimaryHover, t),
    buttonPrimaryIcon: lerpColorNonNull(a.buttonPrimaryIcon, b.buttonPrimaryIcon, t),
    buttonPrimaryIconHover: lerpColorNonNull(a.buttonPrimaryIconHover, b.buttonPrimaryIconHover, t),
    // Icons
    iconFgBrand: lerpColorNonNull(a.iconFgBrand, b.iconFgBrand, t),
    iconFgBrandOnBrand: lerpColorNonNull(a.iconFgBrandOnBrand, b.iconFgBrandOnBrand, t),
    // Alpha
    alphaBlack10: lerpColorNonNull(a.alphaBlack10, b.alphaBlack10, t),
    alphaBlack20: lerpColorNonNull(a.alphaBlack20, b.alphaBlack20, t),
    alphaBlack30: lerpColorNonNull(a.alphaBlack30, b.alphaBlack30, t),
    alphaBlack40: lerpColorNonNull(a.alphaBlack40, b.alphaBlack40, t),
    alphaBlack50: lerpColorNonNull(a.alphaBlack50, b.alphaBlack50, t),
    alphaBlack60: lerpColorNonNull(a.alphaBlack60, b.alphaBlack60, t),
    alphaBlack70: lerpColorNonNull(a.alphaBlack70, b.alphaBlack70, t),
    alphaBlack80: lerpColorNonNull(a.alphaBlack80, b.alphaBlack80, t),
    alphaBlack90: lerpColorNonNull(a.alphaBlack90, b.alphaBlack90, t),
    alphaBlack100: lerpColorNonNull(a.alphaBlack100, b.alphaBlack100, t),
    alphaWhite10: lerpColorNonNull(a.alphaWhite10, b.alphaWhite10, t),
    alphaWhite20: lerpColorNonNull(a.alphaWhite20, b.alphaWhite20, t),
    alphaWhite30: lerpColorNonNull(a.alphaWhite30, b.alphaWhite30, t),
    alphaWhite40: lerpColorNonNull(a.alphaWhite40, b.alphaWhite40, t),
    alphaWhite50: lerpColorNonNull(a.alphaWhite50, b.alphaWhite50, t),
    alphaWhite60: lerpColorNonNull(a.alphaWhite60, b.alphaWhite60, t),
    alphaWhite70: lerpColorNonNull(a.alphaWhite70, b.alphaWhite70, t),
    alphaWhite80: lerpColorNonNull(a.alphaWhite80, b.alphaWhite80, t),
    alphaWhite90: lerpColorNonNull(a.alphaWhite90, b.alphaWhite90, t),
    alphaWhite100: lerpColorNonNull(a.alphaWhite100, b.alphaWhite100, t),
    // Utility
    utilityBlue50: lerpColorNonNull(a.utilityBlue50, b.utilityBlue50, t),
    utilityBlue100: lerpColorNonNull(a.utilityBlue100, b.utilityBlue100, t),
    utilityBlue200: lerpColorNonNull(a.utilityBlue200, b.utilityBlue200, t),
    utilityBlue300: lerpColorNonNull(a.utilityBlue300, b.utilityBlue300, t),
    utilityBlue400: lerpColorNonNull(a.utilityBlue400, b.utilityBlue400, t),
    utilityBlue500: lerpColorNonNull(a.utilityBlue500, b.utilityBlue500, t),
    utilityBlue600: lerpColorNonNull(a.utilityBlue600, b.utilityBlue600, t),
    utilityBlue700: lerpColorNonNull(a.utilityBlue700, b.utilityBlue700, t),
    utilityError50: lerpColorNonNull(a.utilityError50, b.utilityError50, t),
    utilityError100: lerpColorNonNull(a.utilityError100, b.utilityError100, t),
    utilityError200: lerpColorNonNull(a.utilityError200, b.utilityError200, t),
    utilityError300: lerpColorNonNull(a.utilityError300, b.utilityError300, t),
    utilityError400: lerpColorNonNull(a.utilityError400, b.utilityError400, t),
    utilityError500: lerpColorNonNull(a.utilityError500, b.utilityError500, t),
    utilityError600: lerpColorNonNull(a.utilityError600, b.utilityError600, t),
    utilityError700: lerpColorNonNull(a.utilityError700, b.utilityError700, t),
    utilitySuccess50: lerpColorNonNull(a.utilitySuccess50, b.utilitySuccess50, t),
    utilitySuccess100: lerpColorNonNull(a.utilitySuccess100, b.utilitySuccess100, t),
    utilitySuccess200: lerpColorNonNull(a.utilitySuccess200, b.utilitySuccess200, t),
    utilitySuccess300: lerpColorNonNull(a.utilitySuccess300, b.utilitySuccess300, t),
    utilitySuccess400: lerpColorNonNull(a.utilitySuccess400, b.utilitySuccess400, t),
    utilitySuccess500: lerpColorNonNull(a.utilitySuccess500, b.utilitySuccess500, t),
    utilitySuccess600: lerpColorNonNull(a.utilitySuccess600, b.utilitySuccess600, t),
    utilitySuccess700: lerpColorNonNull(a.utilitySuccess700, b.utilitySuccess700, t),
    utilityWarning50: lerpColorNonNull(a.utilityWarning50, b.utilityWarning50, t),
    utilityWarning100: lerpColorNonNull(a.utilityWarning100, b.utilityWarning100, t),
    utilityWarning200: lerpColorNonNull(a.utilityWarning200, b.utilityWarning200, t),
    utilityWarning300: lerpColorNonNull(a.utilityWarning300, b.utilityWarning300, t),
    utilityWarning400: lerpColorNonNull(a.utilityWarning400, b.utilityWarning400, t),
    utilityWarning500: lerpColorNonNull(a.utilityWarning500, b.utilityWarning500, t),
    utilityWarning600: lerpColorNonNull(a.utilityWarning600, b.utilityWarning600, t),
    utilityWarning700: lerpColorNonNull(a.utilityWarning700, b.utilityWarning700, t),
    // Other
    avatarStylesBgNeutral: lerpColorNonNull(a.avatarStylesBgNeutral, b.avatarStylesBgNeutral, t),
    featuredIconLightFgBrand: lerpColorNonNull(a.featuredIconLightFgBrand, b.featuredIconLightFgBrand, t),
    featuredIconLightFgError: lerpColorNonNull(a.featuredIconLightFgError, b.featuredIconLightFgError, t),
    featuredIconLightFgGray: lerpColorNonNull(a.featuredIconLightFgGray, b.featuredIconLightFgGray, t),
    featuredIconLightFgSuccess: lerpColorNonNull(a.featuredIconLightFgSuccess, b.featuredIconLightFgSuccess, t),
    featuredIconLightFgWarning: lerpColorNonNull(a.featuredIconLightFgWarning, b.featuredIconLightFgWarning, t),
    gradientBottom: lerpColorNonNull(a.gradientBottom, b.gradientBottom, t),
    gradientTop: lerpColorNonNull(a.gradientTop, b.gradientTop, t),
    toggleBorder: lerpColorNonNull(a.toggleBorder, b.toggleBorder, t),
    toggleButtonFgDisabled: lerpColorNonNull(a.toggleButtonFgDisabled, b.toggleButtonFgDisabled, t),
    toggleSlimBorderPressed: lerpColorNonNull(a.toggleSlimBorderPressed, b.toggleSlimBorderPressed, t),
    toggleSlimBorderPressedHover: lerpColorNonNull(a.toggleSlimBorderPressedHover, b.toggleSlimBorderPressedHover, t),
  );
}
