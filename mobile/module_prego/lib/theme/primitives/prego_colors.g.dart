// GENERATED CODE - DO NOT MODIFY BY HAND
// To update, export variables from Figma and run:
//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate
// ignore_for_file: lines_longer_than_80_chars

import "package:flutter/material.dart";

import "../../../../utils/lerp_utils.dart";
import "prego_color_primitives.g.dart";

/// Dark mode color tokens matching Figma specifications.
///
/// All colors are static const, enabling compile-time constant expressions.
/// Colors reference [PregoColorPrimitives] where Figma uses an alias,
/// or inline hex where Figma uses a direct value.
abstract final class PregoColorsDark {
  // ===========================================================================
  // Text Colors - Figma: Colors/Text/*
  // ===========================================================================

  /// Figma: Colors/Text/text-brand-primary (900) → Gray (dark mode)/50
  static const Color textBrandPrimary = PregoColorPrimitives.grayDark50;

  /// Figma: Colors/Text/text-brand-secondary (700) → Gray (dark mode)/300
  static const Color textBrandSecondary = PregoColorPrimitives.grayDark300;

  /// Figma: Colors/Text/text-brand-secondary_hover → Gray (dark mode)/200
  static const Color textBrandSecondaryHover = PregoColorPrimitives.grayDark200;

  /// Figma: Colors/Text/text-brand-tertiary (600) → Gray (dark mode)/400
  static const Color textBrandTertiary = PregoColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-brand-tertiary_alt → Brand Blue/200
  static const Color textBrandTertiaryAlt = PregoColorPrimitives.brandBlue200;

  /// Figma: Colors/Text/text-disabled → Gray (dark mode)/500
  static const Color textDisabled = PregoColorPrimitives.grayDark500;

  /// Figma: Colors/Text/text-error-primary (600) → Error/400
  static const Color textErrorPrimary = PregoColorPrimitives.error400;

  /// Figma: Colors/Text/text-error-primary_hover → Error/300
  static const Color textErrorPrimaryHover = PregoColorPrimitives.error300;

  /// Figma: Colors/Text/text-placeholder → Gray (dark mode)/600
  static const Color textPlaceholder = PregoColorPrimitives.grayDark600;

  /// Figma: Colors/Text/text-placeholder_subtle → Gray (dark mode)/700
  static const Color textPlaceholderSubtle = PregoColorPrimitives.grayDark700;

  /// Figma: Colors/Text/text-primary (900) → Gray (dark mode)/25
  static const Color textPrimary = PregoColorPrimitives.grayDark25;

  /// Figma: Colors/Text/text-primary_on-brand → Gray (dark mode)/50
  static const Color textPrimaryOnBrand = PregoColorPrimitives.grayDark50;

  /// Figma: Colors/Text/text-primary_on-white → Base/black
  static const Color textPrimaryOnWhite = PregoColorPrimitives.baseBlack;

  /// Figma: Colors/Text/text-quaternary (500) → Gray (dark mode)/400
  static const Color textQuaternary = PregoColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-quaternary_on-brand → Gray (dark mode)/400
  static const Color textQuaternaryOnBrand = PregoColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-secondary (600) → Gray (dark mode)/400
  static const Color textSecondary = PregoColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-secondary_hover → Gray (dark mode)/200
  static const Color textSecondaryHover = PregoColorPrimitives.grayDark200;

  /// Figma: Colors/Text/text-secondary_on-brand → Base/white
  static const Color textSecondaryOnBrand = PregoColorPrimitives.baseWhite;

  /// Figma: Colors/Text/text-success-primary (600) → Success/400
  static const Color textSuccessPrimary = PregoColorPrimitives.success400;

  /// Figma: Colors/Text/text-tertiary (600) → Gray (light mode)/400
  static const Color textTertiary = PregoColorPrimitives.grayLight400;

  /// Figma: Colors/Text/text-tertiary_hover → Gray (dark mode)/300
  static const Color textTertiaryHover = PregoColorPrimitives.grayDark300;

  /// Figma: Colors/Text/text-tertiary_on-brand → Gray (dark mode)/400
  static const Color textTertiaryOnBrand = PregoColorPrimitives.grayDark400;

  /// Figma: Colors/Text/text-warning-primary (600) → Warning/400
  static const Color textWarningPrimary = PregoColorPrimitives.warning400;

  /// Figma: Colors/Text/text-white → Base/white
  static const Color textWhite = PregoColorPrimitives.baseWhite;

  // ===========================================================================
  // Border Colors - Figma: Colors/Border/*
  // ===========================================================================

  /// Figma: Colors/Border/border-brand → Brand Blue/400
  static const Color borderBrand = PregoColorPrimitives.brandBlue400;

  /// Figma: Colors/Border/border-brand_alt → Gray (dark mode)/700
  static const Color borderBrandAlt = PregoColorPrimitives.grayDark700;

  /// Figma: Colors/Border/border-disabled → Gray (dark mode)/700
  static const Color borderDisabled = PregoColorPrimitives.grayDark700;

  /// Figma: Colors/Border/border-disabled_subtle → Gray (dark mode)/800
  static const Color borderDisabledSubtle = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Border/border-error → Error/400
  static const Color borderError = PregoColorPrimitives.error400;

  /// Figma: Colors/Border/border-error_subtle → Error/500
  static const Color borderErrorSubtle = PregoColorPrimitives.error500;

  /// Figma: Colors/Border/border-inside-reversed-bottom
  static const Color borderInsideReversedBottom = Color(0x008D939C);

  /// Figma: Colors/Border/border-inside-reversed-top
  static const Color borderInsideReversedTop = Color(0xFF303236);

  /// Figma: Colors/Border/border-primary → Gray (dark mode)/700
  static const Color borderPrimary = PregoColorPrimitives.grayDark700;

  /// Figma: Colors/Border/border-reversed → Gray (dark mode)/800
  static const Color borderReversed = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Border/border-secondary → Gray (dark mode)/800
  static const Color borderSecondary = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Border/border-secondary_alt → Base/black
  static const Color borderSecondaryAlt = PregoColorPrimitives.baseBlack;

  /// Figma: Colors/Border/border-tertiary → Gray (dark mode)/800
  static const Color borderTertiary = PregoColorPrimitives.grayDark800;

  // ===========================================================================
  // Foreground Colors - Figma: Colors/Foreground/*
  // ===========================================================================

  /// Figma: Colors/Foreground/fg-brand-primary (600) → Brand Blue/500
  static const Color fgBrandPrimary = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-brand-primary_alt → Gray (dark mode)/300
  static const Color fgBrandPrimaryAlt = PregoColorPrimitives.grayDark300;

  /// Figma: Colors/Foreground/fg-brand-secondary (500) → Gray (dark mode)/500
  static const Color fgBrandSecondary = PregoColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-brand-secondary_alt → Gray (dark mode)/600
  static const Color fgBrandSecondaryAlt = PregoColorPrimitives.grayDark600;

  /// Figma: Colors/Foreground/fg-brand-secondary_hover → Gray (dark mode)/500
  static const Color fgBrandSecondaryHover = PregoColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-disabled → Gray (dark mode)/500
  static const Color fgDisabled = PregoColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-disabled_subtle → Gray (dark mode)/600
  static const Color fgDisabledSubtle = PregoColorPrimitives.grayDark600;

  /// Figma: Colors/Foreground/fg-error-primary → Error/500
  static const Color fgErrorPrimary = PregoColorPrimitives.error500;

  /// Figma: Colors/Foreground/fg-error-secondary → Error/400
  static const Color fgErrorSecondary = PregoColorPrimitives.error400;

  /// Figma: Colors/Foreground/fg-primary (900) → Base/white
  static const Color fgPrimary = PregoColorPrimitives.baseWhite;

  /// Figma: Colors/Foreground/fg-quaternary (400) → Gray (dark mode)/600
  static const Color fgQuaternary = PregoColorPrimitives.grayDark600;

  /// Figma: Colors/Foreground/fg-quaternary_hover → Gray (dark mode)/500
  static const Color fgQuaternaryHover = PregoColorPrimitives.grayDark500;

  /// Figma: Colors/Foreground/fg-secondary (700) → Gray (dark mode)/300
  static const Color fgSecondary = PregoColorPrimitives.grayDark300;

  /// Figma: Colors/Foreground/fg-secondary_hover → Gray (dark mode)/200
  static const Color fgSecondaryHover = PregoColorPrimitives.grayDark200;

  /// Figma: Colors/Foreground/fg-success-primary → Success/500
  static const Color fgSuccessPrimary = PregoColorPrimitives.success500;

  /// Figma: Colors/Foreground/fg-success-secondary → Success/400
  static const Color fgSuccessSecondary = PregoColorPrimitives.success400;

  /// Figma: Colors/Foreground/fg-tertiary (600) → Gray (dark mode)/400
  static const Color fgTertiary = PregoColorPrimitives.grayDark400;

  /// Figma: Colors/Foreground/fg-tertiary_hover → Gray (dark mode)/300
  static const Color fgTertiaryHover = PregoColorPrimitives.grayDark300;

  /// Figma: Colors/Foreground/fg-warning-primary → Warning/500
  static const Color fgWarningPrimary = PregoColorPrimitives.warning500;

  /// Figma: Colors/Foreground/fg-warning-secondary → Warning/400
  static const Color fgWarningSecondary = PregoColorPrimitives.warning400;

  /// Figma: Colors/Foreground/fg-white → Base/white
  static const Color fgWhite = PregoColorPrimitives.baseWhite;

  // ===========================================================================
  // Background Colors - Figma: Colors/Background/*
  // ===========================================================================

  /// Figma: Colors/Background/Black-white-inversed (alpha) → Base/transparent black
  static const Color blackWhiteInversed = PregoColorPrimitives.baseTransparentBlack;

  /// Figma: Colors/Background/bg-active → Gray (dark mode)/800
  static const Color bgActive = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-brand-primary → Brand Blue/500
  static const Color bgBrandPrimary = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Background/bg-brand-primary_alt → Background/bg-secondary
  static const Color bgBrandPrimaryAlt = PregoColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-brand-secondary → Brand Blue/600
  static const Color bgBrandSecondary = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Background/bg-brand-section → Background/bg-secondary
  static const Color bgBrandSection = PregoColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-brand-section_subtle → Gray (dark mode)/950
  static const Color bgBrandSectionSubtle = PregoColorPrimitives.grayDark950;

  /// Figma: Colors/Background/bg-brand-solid → Brand Blue/600
  static const Color bgBrandSolid = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Background/bg-brand-solid_hover → Brand Blue/500
  static const Color bgBrandSolidHover = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Background/bg-brand_hover → Gray (dark mode alpha)/700
  static const Color bgBrandHover = PregoColorPrimitives.grayDarkAlpha700;

  /// Figma: Colors/Background/bg-brand_pressed → Gray (dark mode alpha)/500
  static const Color bgBrandPressed = PregoColorPrimitives.grayDarkAlpha500;

  /// Figma: Colors/Background/bg-destructive_hover → Gray (dark mode alpha)/900
  static const Color bgDestructiveHover = PregoColorPrimitives.grayDarkAlpha900;

  /// Figma: Colors/Background/bg-destructive_pressed → Gray (dark mode alpha)/700
  static const Color bgDestructivePressed = PregoColorPrimitives.grayDarkAlpha700;

  /// Figma: Colors/Background/bg-disabled → Gray (dark mode)/800
  static const Color bgDisabled = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-disabled_subtle → Gray (dark mode)/900
  static const Color bgDisabledSubtle = PregoColorPrimitives.grayDark900;

  /// Figma: Colors/Background/bg-error-primary → Error/950
  static const Color bgErrorPrimary = PregoColorPrimitives.error950;

  /// Figma: Colors/Background/bg-error-secondary → Error/600
  static const Color bgErrorSecondary = PregoColorPrimitives.error600;

  /// Figma: Colors/Background/bg-error-solid → Error/600
  static const Color bgErrorSolid = PregoColorPrimitives.error600;

  /// Figma: Colors/Background/bg-error-solid_hover → Error/500
  static const Color bgErrorSolidHover = PregoColorPrimitives.error500;

  /// Figma: Colors/Background/bg-gray_hover → Gray (dark mode alpha)/800
  static const Color bgGrayHover = PregoColorPrimitives.grayDarkAlpha800;

  /// Figma: Colors/Background/bg-gray_pressed → Gray (dark mode alpha)/600
  static const Color bgGrayPressed = PregoColorPrimitives.grayDarkAlpha600;

  /// Figma: Colors/Background/bg-overlay → Gray (dark mode)/800
  static const Color bgOverlay = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-primary → Gray (dark mode)/950
  static const Color bgPrimary = PregoColorPrimitives.grayDark950;

  /// Figma: Colors/Background/bg-primary-solid → Background/bg-secondary
  static const Color bgPrimarySolid = PregoColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-primary_alt → Background/bg-secondary
  static const Color bgPrimaryAlt = PregoColorsDark.bgSecondary;

  /// Figma: Colors/Background/bg-quaternary → Gray (dark mode)/700
  static const Color bgQuaternary = PregoColorPrimitives.grayDark700;

  /// Figma: Colors/Background/bg-secondary → Gray (dark mode)/900
  static const Color bgSecondary = PregoColorPrimitives.grayDark900;

  /// Figma: Colors/Background/bg-secondary-solid → Gray (dark mode)/600
  static const Color bgSecondarySolid = PregoColorPrimitives.grayDark600;

  /// Figma: Colors/Background/bg-secondary_alt → Background/bg-primary
  static const Color bgSecondaryAlt = PregoColorsDark.bgPrimary;

  /// Figma: Colors/Background/bg-secondary_hover → Gray (dark mode)/800
  static const Color bgSecondaryHover = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-secondary_subtle → Gray (dark mode)/900
  static const Color bgSecondarySubtle = PregoColorPrimitives.grayDark900;

  /// Figma: Colors/Background/bg-success-primary → Success/950
  static const Color bgSuccessPrimary = PregoColorPrimitives.success950;

  /// Figma: Colors/Background/bg-success-secondary → Success/500
  static const Color bgSuccessSecondary = PregoColorPrimitives.success500;

  /// Figma: Colors/Background/bg-success-solid → Success/600
  static const Color bgSuccessSolid = PregoColorPrimitives.success600;

  /// Figma: Colors/Background/bg-tertiary → Gray (dark mode)/800
  static const Color bgTertiary = PregoColorPrimitives.grayDark800;

  /// Figma: Colors/Background/bg-warning-primary → Warning/950
  static const Color bgWarningPrimary = PregoColorPrimitives.warning950;

  /// Figma: Colors/Background/bg-warning-secondary → Warning/600
  static const Color bgWarningSecondary = PregoColorPrimitives.warning600;

  /// Figma: Colors/Background/bg-warning-solid → Warning/500
  static const Color bgWarningSolid = PregoColorPrimitives.warning500;

  /// Figma: Colors/Background/bg_destructive_hover_alt → Error/950
  static const Color bgDestructiveHoverAlt = PregoColorPrimitives.error950;

  /// Figma: Colors/Background/bg_destructive_pressed_alt → Error/800
  static const Color bgDestructivePressedAlt = PregoColorPrimitives.error800;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/*
  // ===========================================================================

  /// Figma: Colors/Effects/Focus rings/focus-ring → Brand Blue/500
  static const Color focusRing = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Effects/Focus rings/focus-ring-error → Error/500
  static const Color focusRingError = PregoColorPrimitives.error500;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/Shadows/*
  // ===========================================================================

  /// Figma: Colors/Effects/Shadows/shadow-2xl_01 → Base/transparent
  static const Color shadow2xl01 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-2xl_02 → Base/transparent
  static const Color shadow2xl02 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-3xl_01 → Base/transparent
  static const Color shadow3xl01 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-3xl_02 → Base/transparent
  static const Color shadow3xl02 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-inversed → Gray (light mode alpha)/200
  static const Color shadowInversed = PregoColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Effects/Shadows/shadow-lg_01 → Base/transparent
  static const Color shadowLg01 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-lg_02 → Base/transparent
  static const Color shadowLg02 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-lg_03 → Base/transparent
  static const Color shadowLg03 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-md_01 → Base/transparent
  static const Color shadowMd01 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-md_02 → Base/transparent
  static const Color shadowMd02 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic
  static const Color skeuomorphicShadow = Color(0x0D0C0E12);

  /// Figma: Colors/Effects/Shadows/shadow-skeumorphic-inner-border
  static const Color skeuomorphicInnerBorder = Color(0x2E0C0E12);

  /// Figma: Colors/Effects/Shadows/shadow-sm_01 → Base/transparent
  static const Color shadowSm01 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-sm_02 → Base/transparent
  static const Color shadowSm02 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xl_01 → Base/transparent
  static const Color shadowXl01 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xl_02 → Base/transparent
  static const Color shadowXl02 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xl_03 → Base/transparent
  static const Color shadowXl03 = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Effects/Shadows/shadow-xs → Base/transparent
  static const Color shadowXs = PregoColorPrimitives.baseTransparent;

  // ===========================================================================
  // Component Colors - Buttons
  // ===========================================================================

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon → Error/300
  static const Color buttonDestructivePrimaryIcon = PregoColorPrimitives.error300;

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon_hover → Error/200
  static const Color buttonDestructivePrimaryIconHover = PregoColorPrimitives.error200;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-background → Gray (dark mode alpha)/900
  static const Color buttonGlassPrimaryBackground = PregoColorPrimitives.grayDarkAlpha900;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-hover → Gray (dark mode alpha)/800
  static const Color buttonGlassPrimaryHover = PregoColorPrimitives.grayDarkAlpha800;

  /// Figma: Component colors/Components/Buttons/button-primary-icon → Brand Blue/300
  static const Color buttonPrimaryIcon = PregoColorPrimitives.brandBlue300;

  /// Figma: Component colors/Components/Buttons/button-primary-icon_hover → Brand Blue/200
  static const Color buttonPrimaryIconHover = PregoColorPrimitives.brandBlue200;

  // ===========================================================================
  // Component Colors - Icons
  // ===========================================================================

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand → Gray (dark mode)/400
  static const Color iconFgBrand = PregoColorPrimitives.grayDark400;

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand_on-brand → Gray (dark mode)/400
  static const Color iconFgBrandOnBrand = PregoColorPrimitives.grayDark400;

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
  static const Color alphaWhite100 = PregoColorPrimitives.grayDark950;

  // ===========================================================================
  // Utility Colors
  // ===========================================================================

  /// Figma: Component colors/Utility/Blue/utility-blue-50 → Brand Blue/900
  static const Color utilityBlue50 = PregoColorPrimitives.brandBlue900;

  /// Figma: Component colors/Utility/Blue/utility-blue-100 → Brand Blue/800
  static const Color utilityBlue100 = PregoColorPrimitives.brandBlue800;

  /// Figma: Component colors/Utility/Blue/utility-blue-200 → Brand Blue/700
  static const Color utilityBlue200 = PregoColorPrimitives.brandBlue700;

  /// Figma: Component colors/Utility/Blue/utility-blue-300 → Brand Blue/600
  static const Color utilityBlue300 = PregoColorPrimitives.brandBlue600;

  /// Figma: Component colors/Utility/Blue/utility-blue-400 → Brand Blue/500
  static const Color utilityBlue400 = PregoColorPrimitives.brandBlue500;

  /// Figma: Component colors/Utility/Blue/utility-blue-500 → Brand Blue/400
  static const Color utilityBlue500 = PregoColorPrimitives.brandBlue400;

  /// Figma: Component colors/Utility/Blue/utility-blue-600 → Brand Blue/300
  static const Color utilityBlue600 = PregoColorPrimitives.brandBlue300;

  /// Figma: Component colors/Utility/Blue/utility-blue-700 → Brand Blue/200
  static const Color utilityBlue700 = PregoColorPrimitives.brandBlue200;

  /// Figma: Component colors/Utility/Error/utility-error-50 → Error/950
  static const Color utilityError50 = PregoColorPrimitives.error950;

  /// Figma: Component colors/Utility/Error/utility-error-100 → Error/900
  static const Color utilityError100 = PregoColorPrimitives.error900;

  /// Figma: Component colors/Utility/Error/utility-error-200 → Error/800
  static const Color utilityError200 = PregoColorPrimitives.error800;

  /// Figma: Component colors/Utility/Error/utility-error-300 → Error/700
  static const Color utilityError300 = PregoColorPrimitives.error700;

  /// Figma: Component colors/Utility/Error/utility-error-400 → Error/600
  static const Color utilityError400 = PregoColorPrimitives.error600;

  /// Figma: Component colors/Utility/Error/utility-error-500 → Error/500
  static const Color utilityError500 = PregoColorPrimitives.error500;

  /// Figma: Component colors/Utility/Error/utility-error-600 → Error/400
  static const Color utilityError600 = PregoColorPrimitives.error400;

  /// Figma: Component colors/Utility/Error/utility-error-700 → Error/300
  static const Color utilityError700 = PregoColorPrimitives.error300;

  /// Figma: Component colors/Utility/Success/utility-success-50 → Success/950
  static const Color utilitySuccess50 = PregoColorPrimitives.success950;

  /// Figma: Component colors/Utility/Success/utility-success-100 → Success/900
  static const Color utilitySuccess100 = PregoColorPrimitives.success900;

  /// Figma: Component colors/Utility/Success/utility-success-200 → Success/800
  static const Color utilitySuccess200 = PregoColorPrimitives.success800;

  /// Figma: Component colors/Utility/Success/utility-success-300 → Success/700
  static const Color utilitySuccess300 = PregoColorPrimitives.success700;

  /// Figma: Component colors/Utility/Success/utility-success-400 → Success/600
  static const Color utilitySuccess400 = PregoColorPrimitives.success600;

  /// Figma: Component colors/Utility/Success/utility-success-500 → Success/500
  static const Color utilitySuccess500 = PregoColorPrimitives.success500;

  /// Figma: Component colors/Utility/Success/utility-success-600 → Success/400
  static const Color utilitySuccess600 = PregoColorPrimitives.success400;

  /// Figma: Component colors/Utility/Success/utility-success-700 → Success/300
  static const Color utilitySuccess700 = PregoColorPrimitives.success300;

  /// Figma: Component colors/Utility/Warning/utility-warning-50 → Warning/950
  static const Color utilityWarning50 = PregoColorPrimitives.warning950;

  /// Figma: Component colors/Utility/Warning/utility-warning-100 → Warning/900
  static const Color utilityWarning100 = PregoColorPrimitives.warning900;

  /// Figma: Component colors/Utility/Warning/utility-warning-200 → Warning/800
  static const Color utilityWarning200 = PregoColorPrimitives.warning800;

  /// Figma: Component colors/Utility/Warning/utility-warning-300 → Warning/700
  static const Color utilityWarning300 = PregoColorPrimitives.warning700;

  /// Figma: Component colors/Utility/Warning/utility-warning-400 → Warning/600
  static const Color utilityWarning400 = PregoColorPrimitives.warning600;

  /// Figma: Component colors/Utility/Warning/utility-warning-500 → Warning/500
  static const Color utilityWarning500 = PregoColorPrimitives.warning500;

  /// Figma: Component colors/Utility/Warning/utility-warning-600 → Warning/400
  static const Color utilityWarning600 = PregoColorPrimitives.warning400;

  /// Figma: Component colors/Utility/Warning/utility-warning-700 → Warning/300
  static const Color utilityWarning700 = PregoColorPrimitives.warning300;

  // ===========================================================================
  // Other
  // ===========================================================================

  /// Figma: Component colors/Components/Avatars/avatar-styles-bg-neutral
  static const Color avatarStylesBgNeutral = Color(0xFFE0E0E0);

  /// Figma: Component colors/Components/Icons/Hero Avatar/brand-gradient-bottom → Brand Blue/300
  static const Color brandGradientBottom = PregoColorPrimitives.brandBlue300;

  /// Figma: Component colors/Components/Icons/Hero Avatar/brand-gradient-top → Base/white
  static const Color brandGradientTop = PregoColorPrimitives.baseWhite;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-brand → Brand Blue/200
  static const Color featuredIconLightFgBrand = PregoColorPrimitives.brandBlue200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-error → Error/200
  static const Color featuredIconLightFgError = PregoColorPrimitives.error200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-gray → Gray (dark mode alpha)/200
  static const Color featuredIconLightFgGray = PregoColorPrimitives.grayDarkAlpha200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-success → Success/200
  static const Color featuredIconLightFgSuccess = PregoColorPrimitives.success200;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-warning → Warning/200
  static const Color featuredIconLightFgWarning = PregoColorPrimitives.warning200;

  /// Figma: Component colors/Components/Icons/Hero Avatar/green-gradient-bottom → Success/200
  static const Color greenGradientBottom = PregoColorPrimitives.success200;

  /// Figma: Component colors/Components/Icons/Hero Avatar/green-gradient-top 2 → Base/white
  static const Color greenGradientTop2 = PregoColorPrimitives.baseWhite;

  /// Figma: Component colors/Components/Icons/Hero Avatar/orange-gradient-bottom → Error/300
  static const Color orangeGradientBottom = PregoColorPrimitives.error300;

  /// Figma: Component colors/Components/Icons/Hero Avatar/orange-gradient-top → Base/white
  static const Color orangeGradientTop = PregoColorPrimitives.baseWhite;

  /// Figma: Component colors/Components/Icons/Hero Avatar/purple-gradient-bottom → Purple/300
  static const Color purpleGradientBottom = PregoColorPrimitives.purple300;

  /// Figma: Component colors/Components/Icons/Hero Avatar/purple-gradient-top → Base/white
  static const Color purpleGradientTop = PregoColorPrimitives.baseWhite;

  /// Figma: Component colors/Components/Toggles/toggle-border → Base/transparent
  static const Color toggleBorder = PregoColorPrimitives.baseTransparent;

  /// Figma: Component colors/Components/Toggles/toggle-button-fg_disabled → Gray (dark mode)/600
  static const Color toggleButtonFgDisabled = PregoColorPrimitives.grayDark600;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed → Base/transparent
  static const Color toggleSlimBorderPressed = PregoColorPrimitives.baseTransparent;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed-hover → Base/transparent
  static const Color toggleSlimBorderPressedHover = PregoColorPrimitives.baseTransparent;
}

/// Light mode color tokens matching Figma specifications.
///
/// All colors are static const, enabling compile-time constant expressions.
/// Colors reference [PregoColorPrimitives] where Figma uses an alias,
/// or inline hex where Figma uses a direct value.
abstract final class PregoColorsLight {
  // ===========================================================================
  // Text Colors - Figma: Colors/Text/*
  // ===========================================================================

  /// Figma: Colors/Text/text-brand-primary (900) → Brand Blue/900
  static const Color textBrandPrimary = PregoColorPrimitives.brandBlue900;

  /// Figma: Colors/Text/text-brand-secondary (700) → Brand Blue/700
  static const Color textBrandSecondary = PregoColorPrimitives.brandBlue700;

  /// Figma: Colors/Text/text-brand-secondary_hover → Brand Blue/800
  static const Color textBrandSecondaryHover = PregoColorPrimitives.brandBlue800;

  /// Figma: Colors/Text/text-brand-tertiary (600) → Brand Blue/600
  static const Color textBrandTertiary = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Text/text-brand-tertiary_alt → Brand Blue/600
  static const Color textBrandTertiaryAlt = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Text/text-disabled → Gray (light mode)/500
  static const Color textDisabled = PregoColorPrimitives.grayLight500;

  /// Figma: Colors/Text/text-error-primary (600) → Error/600
  static const Color textErrorPrimary = PregoColorPrimitives.error600;

  /// Figma: Colors/Text/text-error-primary_hover → Error/700
  static const Color textErrorPrimaryHover = PregoColorPrimitives.error700;

  /// Figma: Colors/Text/text-placeholder → Gray (light mode)/400
  static const Color textPlaceholder = PregoColorPrimitives.grayLight400;

  /// Figma: Colors/Text/text-placeholder_subtle → Gray (light mode)/300
  static const Color textPlaceholderSubtle = PregoColorPrimitives.grayLight300;

  /// Figma: Colors/Text/text-primary (900) → Gray (light mode)/950
  static const Color textPrimary = PregoColorPrimitives.grayLight950;

  /// Figma: Colors/Text/text-primary_on-brand → Base/white
  static const Color textPrimaryOnBrand = PregoColorPrimitives.baseWhite;

  /// Figma: Colors/Text/text-primary_on-white → Base/white
  static const Color textPrimaryOnWhite = PregoColorPrimitives.baseWhite;

  /// Figma: Colors/Text/text-quaternary (500) → Gray (light mode)/400
  static const Color textQuaternary = PregoColorPrimitives.grayLight400;

  /// Figma: Colors/Text/text-quaternary_on-brand → Brand Blue/300
  static const Color textQuaternaryOnBrand = PregoColorPrimitives.brandBlue300;

  /// Figma: Colors/Text/text-secondary (600) → Gray (light mode)/700
  static const Color textSecondary = PregoColorPrimitives.grayLight700;

  /// Figma: Colors/Text/text-secondary_hover → Gray (light mode)/800
  static const Color textSecondaryHover = PregoColorPrimitives.grayLight800;

  /// Figma: Colors/Text/text-secondary_on-brand → Brand Blue/400
  static const Color textSecondaryOnBrand = PregoColorPrimitives.brandBlue400;

  /// Figma: Colors/Text/text-success-primary (600) → Success/600
  static const Color textSuccessPrimary = PregoColorPrimitives.success600;

  /// Figma: Colors/Text/text-tertiary (600) → Gray (light mode)/600
  static const Color textTertiary = PregoColorPrimitives.grayLight600;

  /// Figma: Colors/Text/text-tertiary_hover → Gray (light mode)/700
  static const Color textTertiaryHover = PregoColorPrimitives.grayLight700;

  /// Figma: Colors/Text/text-tertiary_on-brand → Brand Blue/200
  static const Color textTertiaryOnBrand = PregoColorPrimitives.brandBlue200;

  /// Figma: Colors/Text/text-warning-primary (600) → Warning/600
  static const Color textWarningPrimary = PregoColorPrimitives.warning600;

  /// Figma: Colors/Text/text-white → Base/white
  static const Color textWhite = PregoColorPrimitives.baseWhite;

  // ===========================================================================
  // Border Colors - Figma: Colors/Border/*
  // ===========================================================================

  /// Figma: Colors/Border/border-brand → Brand Blue/500
  static const Color borderBrand = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Border/border-brand_alt → Brand Blue/600
  static const Color borderBrandAlt = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Border/border-disabled → Gray (light mode)/300
  static const Color borderDisabled = PregoColorPrimitives.grayLight300;

  /// Figma: Colors/Border/border-disabled_subtle → Gray (light mode)/200
  static const Color borderDisabledSubtle = PregoColorPrimitives.grayLight200;

  /// Figma: Colors/Border/border-error → Error/500
  static const Color borderError = PregoColorPrimitives.error500;

  /// Figma: Colors/Border/border-error_subtle → Error/300
  static const Color borderErrorSubtle = PregoColorPrimitives.error300;

  /// Figma: Colors/Border/border-inside-reversed-bottom
  static const Color borderInsideReversedBottom = Color(0x33000000);

  /// Figma: Colors/Border/border-inside-reversed-top
  static const Color borderInsideReversedTop = Color(0x00FFFFFF);

  /// Figma: Colors/Border/border-primary → Gray (light mode)/300
  static const Color borderPrimary = PregoColorPrimitives.grayLight300;

  /// Figma: Colors/Border/border-reversed → Base/white
  static const Color borderReversed = PregoColorPrimitives.baseWhite;

  /// Figma: Colors/Border/border-secondary → Gray (light mode)/200
  static const Color borderSecondary = PregoColorPrimitives.grayLight200;

  /// Figma: Colors/Border/border-secondary_alt
  static const Color borderSecondaryAlt = Color(0x0D000000);

  /// Figma: Colors/Border/border-tertiary → Gray (light mode)/100
  static const Color borderTertiary = PregoColorPrimitives.grayLight100;

  // ===========================================================================
  // Foreground Colors - Figma: Colors/Foreground/*
  // ===========================================================================

  /// Figma: Colors/Foreground/fg-brand-primary (600) → Brand Blue/600
  static const Color fgBrandPrimary = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Foreground/fg-brand-primary_alt → Brand Blue/600
  static const Color fgBrandPrimaryAlt = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Foreground/fg-brand-secondary (500) → Brand Blue/500
  static const Color fgBrandSecondary = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-brand-secondary_alt → Brand Blue/500
  static const Color fgBrandSecondaryAlt = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-brand-secondary_hover → Brand Blue/500
  static const Color fgBrandSecondaryHover = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Foreground/fg-disabled → Gray (light mode)/400
  static const Color fgDisabled = PregoColorPrimitives.grayLight400;

  /// Figma: Colors/Foreground/fg-disabled_subtle → Gray (light mode)/300
  static const Color fgDisabledSubtle = PregoColorPrimitives.grayLight300;

  /// Figma: Colors/Foreground/fg-error-primary → Error/600
  static const Color fgErrorPrimary = PregoColorPrimitives.error600;

  /// Figma: Colors/Foreground/fg-error-secondary → Error/500
  static const Color fgErrorSecondary = PregoColorPrimitives.error500;

  /// Figma: Colors/Foreground/fg-primary (900) → Gray (dark mode)/900
  static const Color fgPrimary = PregoColorPrimitives.grayDark900;

  /// Figma: Colors/Foreground/fg-quaternary (400) → Gray (light mode)/400
  static const Color fgQuaternary = PregoColorPrimitives.grayLight400;

  /// Figma: Colors/Foreground/fg-quaternary_hover → Gray (light mode)/500
  static const Color fgQuaternaryHover = PregoColorPrimitives.grayLight500;

  /// Figma: Colors/Foreground/fg-secondary (700) → Gray (light mode)/700
  static const Color fgSecondary = PregoColorPrimitives.grayLight700;

  /// Figma: Colors/Foreground/fg-secondary_hover → Gray (light mode)/800
  static const Color fgSecondaryHover = PregoColorPrimitives.grayLight800;

  /// Figma: Colors/Foreground/fg-success-primary → Success/600
  static const Color fgSuccessPrimary = PregoColorPrimitives.success600;

  /// Figma: Colors/Foreground/fg-success-secondary → Success/500
  static const Color fgSuccessSecondary = PregoColorPrimitives.success500;

  /// Figma: Colors/Foreground/fg-tertiary (600) → Gray (light mode)/600
  static const Color fgTertiary = PregoColorPrimitives.grayLight600;

  /// Figma: Colors/Foreground/fg-tertiary_hover → Gray (light mode)/700
  static const Color fgTertiaryHover = PregoColorPrimitives.grayLight700;

  /// Figma: Colors/Foreground/fg-warning-primary → Warning/600
  static const Color fgWarningPrimary = PregoColorPrimitives.warning600;

  /// Figma: Colors/Foreground/fg-warning-secondary → Warning/500
  static const Color fgWarningSecondary = PregoColorPrimitives.warning500;

  /// Figma: Colors/Foreground/fg-white → Base/white
  static const Color fgWhite = PregoColorPrimitives.baseWhite;

  // ===========================================================================
  // Background Colors - Figma: Colors/Background/*
  // ===========================================================================

  /// Figma: Colors/Background/Black-white-inversed (alpha) → Base/transparent
  static const Color blackWhiteInversed = PregoColorPrimitives.baseTransparent;

  /// Figma: Colors/Background/bg-active → Gray (light mode)/50
  static const Color bgActive = PregoColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-brand-primary → Brand Blue/50
  static const Color bgBrandPrimary = PregoColorPrimitives.brandBlue50;

  /// Figma: Colors/Background/bg-brand-primary_alt → Brand Blue/50
  static const Color bgBrandPrimaryAlt = PregoColorPrimitives.brandBlue50;

  /// Figma: Colors/Background/bg-brand-secondary → Brand Blue/100
  static const Color bgBrandSecondary = PregoColorPrimitives.brandBlue100;

  /// Figma: Colors/Background/bg-brand-section → Brand Blue/800
  static const Color bgBrandSection = PregoColorPrimitives.brandBlue800;

  /// Figma: Colors/Background/bg-brand-section_subtle → Gray (light mode)/100
  static const Color bgBrandSectionSubtle = PregoColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-brand-solid → Brand Blue/600
  static const Color bgBrandSolid = PregoColorPrimitives.brandBlue600;

  /// Figma: Colors/Background/bg-brand-solid_hover → Brand Blue/700
  static const Color bgBrandSolidHover = PregoColorPrimitives.brandBlue700;

  /// Figma: Colors/Background/bg-brand_hover → Gray (light mode alpha)/200
  static const Color bgBrandHover = PregoColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Background/bg-brand_pressed → Gray (light mode alpha)/300
  static const Color bgBrandPressed = PregoColorPrimitives.grayLightAlpha300;

  /// Figma: Colors/Background/bg-destructive_hover → Gray (light mode alpha)/200
  static const Color bgDestructiveHover = PregoColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Background/bg-destructive_pressed → Gray (light mode alpha)/400
  static const Color bgDestructivePressed = PregoColorPrimitives.grayLightAlpha400;

  /// Figma: Colors/Background/bg-disabled → Gray (light mode)/100
  static const Color bgDisabled = PregoColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-disabled_subtle → Gray (light mode)/50
  static const Color bgDisabledSubtle = PregoColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-error-primary → Error/50
  static const Color bgErrorPrimary = PregoColorPrimitives.error50;

  /// Figma: Colors/Background/bg-error-secondary → Error/100
  static const Color bgErrorSecondary = PregoColorPrimitives.error100;

  /// Figma: Colors/Background/bg-error-solid → Error/600
  static const Color bgErrorSolid = PregoColorPrimitives.error600;

  /// Figma: Colors/Background/bg-error-solid_hover → Error/700
  static const Color bgErrorSolidHover = PregoColorPrimitives.error700;

  /// Figma: Colors/Background/bg-gray_hover → Gray (light mode alpha)/50
  static const Color bgGrayHover = PregoColorPrimitives.grayLightAlpha50;

  /// Figma: Colors/Background/bg-gray_pressed → Gray (light mode alpha)/200
  static const Color bgGrayPressed = PregoColorPrimitives.grayLightAlpha200;

  /// Figma: Colors/Background/bg-overlay → Gray (light mode)/950
  static const Color bgOverlay = PregoColorPrimitives.grayLight950;

  /// Figma: Colors/Background/bg-primary → Base/white
  static const Color bgPrimary = PregoColorPrimitives.baseWhite;

  /// Figma: Colors/Background/bg-primary-solid → Gray (light mode)/950
  static const Color bgPrimarySolid = PregoColorPrimitives.grayLight950;

  /// Figma: Colors/Background/bg-primary_alt → Gray (light mode)/25
  static const Color bgPrimaryAlt = PregoColorPrimitives.grayLight25;

  /// Figma: Colors/Background/bg-quaternary → Gray (light mode)/200
  static const Color bgQuaternary = PregoColorPrimitives.grayLight200;

  /// Figma: Colors/Background/bg-secondary → Gray (light mode)/50
  static const Color bgSecondary = PregoColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-secondary-solid → Gray (light mode)/600
  static const Color bgSecondarySolid = PregoColorPrimitives.grayLight600;

  /// Figma: Colors/Background/bg-secondary_alt → Gray (light mode)/50
  static const Color bgSecondaryAlt = PregoColorPrimitives.grayLight50;

  /// Figma: Colors/Background/bg-secondary_hover → Gray (light mode)/100
  static const Color bgSecondaryHover = PregoColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-secondary_subtle → Gray (light mode)/25
  static const Color bgSecondarySubtle = PregoColorPrimitives.grayLight25;

  /// Figma: Colors/Background/bg-success-primary → Success/50
  static const Color bgSuccessPrimary = PregoColorPrimitives.success50;

  /// Figma: Colors/Background/bg-success-secondary → Success/100
  static const Color bgSuccessSecondary = PregoColorPrimitives.success100;

  /// Figma: Colors/Background/bg-success-solid → Success/600
  static const Color bgSuccessSolid = PregoColorPrimitives.success600;

  /// Figma: Colors/Background/bg-tertiary → Gray (light mode)/100
  static const Color bgTertiary = PregoColorPrimitives.grayLight100;

  /// Figma: Colors/Background/bg-warning-primary → Warning/50
  static const Color bgWarningPrimary = PregoColorPrimitives.warning50;

  /// Figma: Colors/Background/bg-warning-secondary → Warning/100
  static const Color bgWarningSecondary = PregoColorPrimitives.warning100;

  /// Figma: Colors/Background/bg-warning-solid → Warning/600
  static const Color bgWarningSolid = PregoColorPrimitives.warning600;

  /// Figma: Colors/Background/bg_destructive_hover_alt → Error/50
  static const Color bgDestructiveHoverAlt = PregoColorPrimitives.error50;

  /// Figma: Colors/Background/bg_destructive_pressed_alt → Error/200
  static const Color bgDestructivePressedAlt = PregoColorPrimitives.error200;

  // ===========================================================================
  // Effects - Figma: Colors/Effects/*
  // ===========================================================================

  /// Figma: Colors/Effects/Focus rings/focus-ring → Brand Blue/500
  static const Color focusRing = PregoColorPrimitives.brandBlue500;

  /// Figma: Colors/Effects/Focus rings/focus-ring-error → Error/500
  static const Color focusRingError = PregoColorPrimitives.error500;

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
  static const Color buttonDestructivePrimaryIcon = PregoColorPrimitives.error300;

  /// Figma: Component colors/Components/Buttons/button-destructive-primary-icon_hover → Error/200
  static const Color buttonDestructivePrimaryIconHover = PregoColorPrimitives.error200;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-background → Gray (light mode alpha)/50
  static const Color buttonGlassPrimaryBackground = PregoColorPrimitives.grayLightAlpha50;

  /// Figma: Component colors/Components/Buttons/button-glass- primary-hover → Gray (light mode alpha)/100
  static const Color buttonGlassPrimaryHover = PregoColorPrimitives.grayLightAlpha100;

  /// Figma: Component colors/Components/Buttons/button-primary-icon → Brand Blue/300
  static const Color buttonPrimaryIcon = PregoColorPrimitives.brandBlue300;

  /// Figma: Component colors/Components/Buttons/button-primary-icon_hover → Brand Blue/200
  static const Color buttonPrimaryIconHover = PregoColorPrimitives.brandBlue200;

  // ===========================================================================
  // Component Colors - Icons
  // ===========================================================================

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand → Brand Blue/600
  static const Color iconFgBrand = PregoColorPrimitives.brandBlue600;

  /// Figma: Component colors/Components/Icons/Icons/icon-fg-brand_on-brand → Brand Blue/200
  static const Color iconFgBrandOnBrand = PregoColorPrimitives.brandBlue200;

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
  static const Color utilityBlue50 = PregoColorPrimitives.brandBlue50;

  /// Figma: Component colors/Utility/Blue/utility-blue-100 → Brand Blue/100
  static const Color utilityBlue100 = PregoColorPrimitives.brandBlue100;

  /// Figma: Component colors/Utility/Blue/utility-blue-200 → Brand Blue/200
  static const Color utilityBlue200 = PregoColorPrimitives.brandBlue200;

  /// Figma: Component colors/Utility/Blue/utility-blue-300 → Brand Blue/300
  static const Color utilityBlue300 = PregoColorPrimitives.brandBlue300;

  /// Figma: Component colors/Utility/Blue/utility-blue-400 → Brand Blue/400
  static const Color utilityBlue400 = PregoColorPrimitives.brandBlue400;

  /// Figma: Component colors/Utility/Blue/utility-blue-500 → Brand Blue/500
  static const Color utilityBlue500 = PregoColorPrimitives.brandBlue500;

  /// Figma: Component colors/Utility/Blue/utility-blue-600 → Brand Blue/600
  static const Color utilityBlue600 = PregoColorPrimitives.brandBlue600;

  /// Figma: Component colors/Utility/Blue/utility-blue-700 → Brand Blue/700
  static const Color utilityBlue700 = PregoColorPrimitives.brandBlue700;

  /// Figma: Component colors/Utility/Error/utility-error-50 → Error/50
  static const Color utilityError50 = PregoColorPrimitives.error50;

  /// Figma: Component colors/Utility/Error/utility-error-100 → Error/100
  static const Color utilityError100 = PregoColorPrimitives.error100;

  /// Figma: Component colors/Utility/Error/utility-error-200 → Error/200
  static const Color utilityError200 = PregoColorPrimitives.error200;

  /// Figma: Component colors/Utility/Error/utility-error-300 → Error/300
  static const Color utilityError300 = PregoColorPrimitives.error300;

  /// Figma: Component colors/Utility/Error/utility-error-400 → Error/400
  static const Color utilityError400 = PregoColorPrimitives.error400;

  /// Figma: Component colors/Utility/Error/utility-error-500 → Error/500
  static const Color utilityError500 = PregoColorPrimitives.error500;

  /// Figma: Component colors/Utility/Error/utility-error-600 → Error/600
  static const Color utilityError600 = PregoColorPrimitives.error600;

  /// Figma: Component colors/Utility/Error/utility-error-700 → Error/700
  static const Color utilityError700 = PregoColorPrimitives.error700;

  /// Figma: Component colors/Utility/Success/utility-success-50 → Success/50
  static const Color utilitySuccess50 = PregoColorPrimitives.success50;

  /// Figma: Component colors/Utility/Success/utility-success-100 → Success/100
  static const Color utilitySuccess100 = PregoColorPrimitives.success100;

  /// Figma: Component colors/Utility/Success/utility-success-200 → Success/200
  static const Color utilitySuccess200 = PregoColorPrimitives.success200;

  /// Figma: Component colors/Utility/Success/utility-success-300 → Success/300
  static const Color utilitySuccess300 = PregoColorPrimitives.success300;

  /// Figma: Component colors/Utility/Success/utility-success-400 → Success/400
  static const Color utilitySuccess400 = PregoColorPrimitives.success400;

  /// Figma: Component colors/Utility/Success/utility-success-500 → Success/500
  static const Color utilitySuccess500 = PregoColorPrimitives.success500;

  /// Figma: Component colors/Utility/Success/utility-success-600 → Success/600
  static const Color utilitySuccess600 = PregoColorPrimitives.success600;

  /// Figma: Component colors/Utility/Success/utility-success-700 → Success/700
  static const Color utilitySuccess700 = PregoColorPrimitives.success700;

  /// Figma: Component colors/Utility/Warning/utility-warning-50 → Warning/50
  static const Color utilityWarning50 = PregoColorPrimitives.warning50;

  /// Figma: Component colors/Utility/Warning/utility-warning-100 → Warning/100
  static const Color utilityWarning100 = PregoColorPrimitives.warning100;

  /// Figma: Component colors/Utility/Warning/utility-warning-200 → Warning/200
  static const Color utilityWarning200 = PregoColorPrimitives.warning200;

  /// Figma: Component colors/Utility/Warning/utility-warning-300 → Warning/300
  static const Color utilityWarning300 = PregoColorPrimitives.warning300;

  /// Figma: Component colors/Utility/Warning/utility-warning-400 → Warning/400
  static const Color utilityWarning400 = PregoColorPrimitives.warning400;

  /// Figma: Component colors/Utility/Warning/utility-warning-500 → Warning/500
  static const Color utilityWarning500 = PregoColorPrimitives.warning500;

  /// Figma: Component colors/Utility/Warning/utility-warning-600 → Warning/600
  static const Color utilityWarning600 = PregoColorPrimitives.warning600;

  /// Figma: Component colors/Utility/Warning/utility-warning-700 → Warning/700
  static const Color utilityWarning700 = PregoColorPrimitives.warning700;

  // ===========================================================================
  // Other
  // ===========================================================================

  /// Figma: Component colors/Components/Avatars/avatar-styles-bg-neutral
  static const Color avatarStylesBgNeutral = Color(0xFFE0E0E0);

  /// Figma: Component colors/Components/Icons/Hero Avatar/brand-gradient-bottom → Brand Blue/700
  static const Color brandGradientBottom = PregoColorPrimitives.brandBlue700;

  /// Figma: Component colors/Components/Icons/Hero Avatar/brand-gradient-top → Brand Blue/400
  static const Color brandGradientTop = PregoColorPrimitives.brandBlue400;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-brand → Brand Blue/600
  static const Color featuredIconLightFgBrand = PregoColorPrimitives.brandBlue600;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-error → Error/600
  static const Color featuredIconLightFgError = PregoColorPrimitives.error600;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-gray → Gray (light mode)/500
  static const Color featuredIconLightFgGray = PregoColorPrimitives.grayLight500;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-success → Success/600
  static const Color featuredIconLightFgSuccess = PregoColorPrimitives.success600;

  /// Figma: Component colors/Components/Icons/Featured icons/featured-icon-light-fg-warning → Warning/600
  static const Color featuredIconLightFgWarning = PregoColorPrimitives.warning600;

  /// Figma: Component colors/Components/Icons/Hero Avatar/green-gradient-bottom → Success/900
  static const Color greenGradientBottom = PregoColorPrimitives.success900;

  /// Figma: Component colors/Components/Icons/Hero Avatar/green-gradient-top 2 → Success/300
  static const Color greenGradientTop2 = PregoColorPrimitives.success300;

  /// Figma: Component colors/Components/Icons/Hero Avatar/orange-gradient-bottom → Error/600
  static const Color orangeGradientBottom = PregoColorPrimitives.error600;

  /// Figma: Component colors/Components/Icons/Hero Avatar/orange-gradient-top → Warning/600
  static const Color orangeGradientTop = PregoColorPrimitives.warning600;

  /// Figma: Component colors/Components/Icons/Hero Avatar/purple-gradient-bottom → Purple/900
  static const Color purpleGradientBottom = PregoColorPrimitives.purple900;

  /// Figma: Component colors/Components/Icons/Hero Avatar/purple-gradient-top → Purple/300
  static const Color purpleGradientTop = PregoColorPrimitives.purple300;

  /// Figma: Component colors/Components/Toggles/toggle-border → Gray (light mode)/300
  static const Color toggleBorder = PregoColorPrimitives.grayLight300;

  /// Figma: Component colors/Components/Toggles/toggle-button-fg_disabled → Gray (light mode)/50
  static const Color toggleButtonFgDisabled = PregoColorPrimitives.grayLight50;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed → Background/bg-brand-solid
  static const Color toggleSlimBorderPressed = PregoColorsLight.bgBrandSolid;

  /// Figma: Component colors/Components/Toggles/toggle-slim-border_pressed-hover → Background/bg-brand-solid_hover
  static const Color toggleSlimBorderPressedHover = PregoColorsLight.bgBrandSolidHover;
}

/// Semantic color tokens that adapt to light/dark mode.
///
/// Maps directly to Figma "Color modes" variables.
/// Property names follow Figma naming: `text-primary` → `textPrimary`.
///
/// Usage via `context.prego`:
/// ```dart
/// Container(
///   color: context.prego.colors.bgPrimary,
///   child: Text(
///     'Hello',
///     style: TextStyle(color: context.prego.colors.textPrimary),
///   ),
/// )
/// ```
@immutable
// ignore: use_enums
final class PregoColors {
  // ===========================================================================
  // Dark Mode - Figma: Color mode = Dark
  // ===========================================================================

  static const dark = PregoColors._(
    brightness: Brightness.dark,
    // Text
    textBrandPrimary: PregoColorsDark.textBrandPrimary,
    textBrandSecondary: PregoColorsDark.textBrandSecondary,
    textBrandSecondaryHover: PregoColorsDark.textBrandSecondaryHover,
    textBrandTertiary: PregoColorsDark.textBrandTertiary,
    textBrandTertiaryAlt: PregoColorsDark.textBrandTertiaryAlt,
    textDisabled: PregoColorsDark.textDisabled,
    textErrorPrimary: PregoColorsDark.textErrorPrimary,
    textErrorPrimaryHover: PregoColorsDark.textErrorPrimaryHover,
    textPlaceholder: PregoColorsDark.textPlaceholder,
    textPlaceholderSubtle: PregoColorsDark.textPlaceholderSubtle,
    textPrimary: PregoColorsDark.textPrimary,
    textPrimaryOnBrand: PregoColorsDark.textPrimaryOnBrand,
    textPrimaryOnWhite: PregoColorsDark.textPrimaryOnWhite,
    textQuaternary: PregoColorsDark.textQuaternary,
    textQuaternaryOnBrand: PregoColorsDark.textQuaternaryOnBrand,
    textSecondary: PregoColorsDark.textSecondary,
    textSecondaryHover: PregoColorsDark.textSecondaryHover,
    textSecondaryOnBrand: PregoColorsDark.textSecondaryOnBrand,
    textSuccessPrimary: PregoColorsDark.textSuccessPrimary,
    textTertiary: PregoColorsDark.textTertiary,
    textTertiaryHover: PregoColorsDark.textTertiaryHover,
    textTertiaryOnBrand: PregoColorsDark.textTertiaryOnBrand,
    textWarningPrimary: PregoColorsDark.textWarningPrimary,
    textWhite: PregoColorsDark.textWhite,
    // Border
    borderBrand: PregoColorsDark.borderBrand,
    borderBrandAlt: PregoColorsDark.borderBrandAlt,
    borderDisabled: PregoColorsDark.borderDisabled,
    borderDisabledSubtle: PregoColorsDark.borderDisabledSubtle,
    borderError: PregoColorsDark.borderError,
    borderErrorSubtle: PregoColorsDark.borderErrorSubtle,
    borderInsideReversedBottom: PregoColorsDark.borderInsideReversedBottom,
    borderInsideReversedTop: PregoColorsDark.borderInsideReversedTop,
    borderPrimary: PregoColorsDark.borderPrimary,
    borderReversed: PregoColorsDark.borderReversed,
    borderSecondary: PregoColorsDark.borderSecondary,
    borderSecondaryAlt: PregoColorsDark.borderSecondaryAlt,
    borderTertiary: PregoColorsDark.borderTertiary,
    // Foreground
    fgBrandPrimary: PregoColorsDark.fgBrandPrimary,
    fgBrandPrimaryAlt: PregoColorsDark.fgBrandPrimaryAlt,
    fgBrandSecondary: PregoColorsDark.fgBrandSecondary,
    fgBrandSecondaryAlt: PregoColorsDark.fgBrandSecondaryAlt,
    fgBrandSecondaryHover: PregoColorsDark.fgBrandSecondaryHover,
    fgDisabled: PregoColorsDark.fgDisabled,
    fgDisabledSubtle: PregoColorsDark.fgDisabledSubtle,
    fgErrorPrimary: PregoColorsDark.fgErrorPrimary,
    fgErrorSecondary: PregoColorsDark.fgErrorSecondary,
    fgPrimary: PregoColorsDark.fgPrimary,
    fgQuaternary: PregoColorsDark.fgQuaternary,
    fgQuaternaryHover: PregoColorsDark.fgQuaternaryHover,
    fgSecondary: PregoColorsDark.fgSecondary,
    fgSecondaryHover: PregoColorsDark.fgSecondaryHover,
    fgSuccessPrimary: PregoColorsDark.fgSuccessPrimary,
    fgSuccessSecondary: PregoColorsDark.fgSuccessSecondary,
    fgTertiary: PregoColorsDark.fgTertiary,
    fgTertiaryHover: PregoColorsDark.fgTertiaryHover,
    fgWarningPrimary: PregoColorsDark.fgWarningPrimary,
    fgWarningSecondary: PregoColorsDark.fgWarningSecondary,
    fgWhite: PregoColorsDark.fgWhite,
    // Background
    blackWhiteInversed: PregoColorsDark.blackWhiteInversed,
    bgActive: PregoColorsDark.bgActive,
    bgBrandPrimary: PregoColorsDark.bgBrandPrimary,
    bgBrandPrimaryAlt: PregoColorsDark.bgBrandPrimaryAlt,
    bgBrandSecondary: PregoColorsDark.bgBrandSecondary,
    bgBrandSection: PregoColorsDark.bgBrandSection,
    bgBrandSectionSubtle: PregoColorsDark.bgBrandSectionSubtle,
    bgBrandSolid: PregoColorsDark.bgBrandSolid,
    bgBrandSolidHover: PregoColorsDark.bgBrandSolidHover,
    bgBrandHover: PregoColorsDark.bgBrandHover,
    bgBrandPressed: PregoColorsDark.bgBrandPressed,
    bgDestructiveHover: PregoColorsDark.bgDestructiveHover,
    bgDestructivePressed: PregoColorsDark.bgDestructivePressed,
    bgDisabled: PregoColorsDark.bgDisabled,
    bgDisabledSubtle: PregoColorsDark.bgDisabledSubtle,
    bgErrorPrimary: PregoColorsDark.bgErrorPrimary,
    bgErrorSecondary: PregoColorsDark.bgErrorSecondary,
    bgErrorSolid: PregoColorsDark.bgErrorSolid,
    bgErrorSolidHover: PregoColorsDark.bgErrorSolidHover,
    bgGrayHover: PregoColorsDark.bgGrayHover,
    bgGrayPressed: PregoColorsDark.bgGrayPressed,
    bgOverlay: PregoColorsDark.bgOverlay,
    bgPrimary: PregoColorsDark.bgPrimary,
    bgPrimarySolid: PregoColorsDark.bgPrimarySolid,
    bgPrimaryAlt: PregoColorsDark.bgPrimaryAlt,
    bgQuaternary: PregoColorsDark.bgQuaternary,
    bgSecondary: PregoColorsDark.bgSecondary,
    bgSecondarySolid: PregoColorsDark.bgSecondarySolid,
    bgSecondaryAlt: PregoColorsDark.bgSecondaryAlt,
    bgSecondaryHover: PregoColorsDark.bgSecondaryHover,
    bgSecondarySubtle: PregoColorsDark.bgSecondarySubtle,
    bgSuccessPrimary: PregoColorsDark.bgSuccessPrimary,
    bgSuccessSecondary: PregoColorsDark.bgSuccessSecondary,
    bgSuccessSolid: PregoColorsDark.bgSuccessSolid,
    bgTertiary: PregoColorsDark.bgTertiary,
    bgWarningPrimary: PregoColorsDark.bgWarningPrimary,
    bgWarningSecondary: PregoColorsDark.bgWarningSecondary,
    bgWarningSolid: PregoColorsDark.bgWarningSolid,
    bgDestructiveHoverAlt: PregoColorsDark.bgDestructiveHoverAlt,
    bgDestructivePressedAlt: PregoColorsDark.bgDestructivePressedAlt,
    // Effects
    focusRing: PregoColorsDark.focusRing,
    focusRingError: PregoColorsDark.focusRingError,
    // Shadows
    shadow2xl01: PregoColorsDark.shadow2xl01,
    shadow2xl02: PregoColorsDark.shadow2xl02,
    shadow3xl01: PregoColorsDark.shadow3xl01,
    shadow3xl02: PregoColorsDark.shadow3xl02,
    shadowInversed: PregoColorsDark.shadowInversed,
    shadowLg01: PregoColorsDark.shadowLg01,
    shadowLg02: PregoColorsDark.shadowLg02,
    shadowLg03: PregoColorsDark.shadowLg03,
    shadowMd01: PregoColorsDark.shadowMd01,
    shadowMd02: PregoColorsDark.shadowMd02,
    skeuomorphicShadow: PregoColorsDark.skeuomorphicShadow,
    skeuomorphicInnerBorder: PregoColorsDark.skeuomorphicInnerBorder,
    shadowSm01: PregoColorsDark.shadowSm01,
    shadowSm02: PregoColorsDark.shadowSm02,
    shadowXl01: PregoColorsDark.shadowXl01,
    shadowXl02: PregoColorsDark.shadowXl02,
    shadowXl03: PregoColorsDark.shadowXl03,
    shadowXs: PregoColorsDark.shadowXs,
    // Buttons
    buttonDestructivePrimaryIcon: PregoColorsDark.buttonDestructivePrimaryIcon,
    buttonDestructivePrimaryIconHover: PregoColorsDark.buttonDestructivePrimaryIconHover,
    buttonGlassPrimaryBackground: PregoColorsDark.buttonGlassPrimaryBackground,
    buttonGlassPrimaryHover: PregoColorsDark.buttonGlassPrimaryHover,
    buttonPrimaryIcon: PregoColorsDark.buttonPrimaryIcon,
    buttonPrimaryIconHover: PregoColorsDark.buttonPrimaryIconHover,
    // Icons
    iconFgBrand: PregoColorsDark.iconFgBrand,
    iconFgBrandOnBrand: PregoColorsDark.iconFgBrandOnBrand,
    // Alpha
    alphaBlack10: PregoColorsDark.alphaBlack10,
    alphaBlack20: PregoColorsDark.alphaBlack20,
    alphaBlack30: PregoColorsDark.alphaBlack30,
    alphaBlack40: PregoColorsDark.alphaBlack40,
    alphaBlack50: PregoColorsDark.alphaBlack50,
    alphaBlack60: PregoColorsDark.alphaBlack60,
    alphaBlack70: PregoColorsDark.alphaBlack70,
    alphaBlack80: PregoColorsDark.alphaBlack80,
    alphaBlack90: PregoColorsDark.alphaBlack90,
    alphaBlack100: PregoColorsDark.alphaBlack100,
    alphaWhite10: PregoColorsDark.alphaWhite10,
    alphaWhite20: PregoColorsDark.alphaWhite20,
    alphaWhite30: PregoColorsDark.alphaWhite30,
    alphaWhite40: PregoColorsDark.alphaWhite40,
    alphaWhite50: PregoColorsDark.alphaWhite50,
    alphaWhite60: PregoColorsDark.alphaWhite60,
    alphaWhite70: PregoColorsDark.alphaWhite70,
    alphaWhite80: PregoColorsDark.alphaWhite80,
    alphaWhite90: PregoColorsDark.alphaWhite90,
    alphaWhite100: PregoColorsDark.alphaWhite100,
    // Utility
    utilityBlue50: PregoColorsDark.utilityBlue50,
    utilityBlue100: PregoColorsDark.utilityBlue100,
    utilityBlue200: PregoColorsDark.utilityBlue200,
    utilityBlue300: PregoColorsDark.utilityBlue300,
    utilityBlue400: PregoColorsDark.utilityBlue400,
    utilityBlue500: PregoColorsDark.utilityBlue500,
    utilityBlue600: PregoColorsDark.utilityBlue600,
    utilityBlue700: PregoColorsDark.utilityBlue700,
    utilityError50: PregoColorsDark.utilityError50,
    utilityError100: PregoColorsDark.utilityError100,
    utilityError200: PregoColorsDark.utilityError200,
    utilityError300: PregoColorsDark.utilityError300,
    utilityError400: PregoColorsDark.utilityError400,
    utilityError500: PregoColorsDark.utilityError500,
    utilityError600: PregoColorsDark.utilityError600,
    utilityError700: PregoColorsDark.utilityError700,
    utilitySuccess50: PregoColorsDark.utilitySuccess50,
    utilitySuccess100: PregoColorsDark.utilitySuccess100,
    utilitySuccess200: PregoColorsDark.utilitySuccess200,
    utilitySuccess300: PregoColorsDark.utilitySuccess300,
    utilitySuccess400: PregoColorsDark.utilitySuccess400,
    utilitySuccess500: PregoColorsDark.utilitySuccess500,
    utilitySuccess600: PregoColorsDark.utilitySuccess600,
    utilitySuccess700: PregoColorsDark.utilitySuccess700,
    utilityWarning50: PregoColorsDark.utilityWarning50,
    utilityWarning100: PregoColorsDark.utilityWarning100,
    utilityWarning200: PregoColorsDark.utilityWarning200,
    utilityWarning300: PregoColorsDark.utilityWarning300,
    utilityWarning400: PregoColorsDark.utilityWarning400,
    utilityWarning500: PregoColorsDark.utilityWarning500,
    utilityWarning600: PregoColorsDark.utilityWarning600,
    utilityWarning700: PregoColorsDark.utilityWarning700,
    // Other
    avatarStylesBgNeutral: PregoColorsDark.avatarStylesBgNeutral,
    brandGradientBottom: PregoColorsDark.brandGradientBottom,
    brandGradientTop: PregoColorsDark.brandGradientTop,
    featuredIconLightFgBrand: PregoColorsDark.featuredIconLightFgBrand,
    featuredIconLightFgError: PregoColorsDark.featuredIconLightFgError,
    featuredIconLightFgGray: PregoColorsDark.featuredIconLightFgGray,
    featuredIconLightFgSuccess: PregoColorsDark.featuredIconLightFgSuccess,
    featuredIconLightFgWarning: PregoColorsDark.featuredIconLightFgWarning,
    greenGradientBottom: PregoColorsDark.greenGradientBottom,
    greenGradientTop2: PregoColorsDark.greenGradientTop2,
    orangeGradientBottom: PregoColorsDark.orangeGradientBottom,
    orangeGradientTop: PregoColorsDark.orangeGradientTop,
    purpleGradientBottom: PregoColorsDark.purpleGradientBottom,
    purpleGradientTop: PregoColorsDark.purpleGradientTop,
    toggleBorder: PregoColorsDark.toggleBorder,
    toggleButtonFgDisabled: PregoColorsDark.toggleButtonFgDisabled,
    toggleSlimBorderPressed: PregoColorsDark.toggleSlimBorderPressed,
    toggleSlimBorderPressedHover: PregoColorsDark.toggleSlimBorderPressedHover,
  );

  const PregoColors._({
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
    required this.brandGradientBottom,
    required this.brandGradientTop,
    required this.featuredIconLightFgBrand,
    required this.featuredIconLightFgError,
    required this.featuredIconLightFgGray,
    required this.featuredIconLightFgSuccess,
    required this.featuredIconLightFgWarning,
    required this.greenGradientBottom,
    required this.greenGradientTop2,
    required this.orangeGradientBottom,
    required this.orangeGradientTop,
    required this.purpleGradientBottom,
    required this.purpleGradientTop,
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

  /// Figma: Component colors/Components/Icons/Hero Avatar/brand-gradient-bottom
  final Color brandGradientBottom;

  /// Figma: Component colors/Components/Icons/Hero Avatar/brand-gradient-top
  final Color brandGradientTop;

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

  /// Figma: Component colors/Components/Icons/Hero Avatar/green-gradient-bottom
  final Color greenGradientBottom;

  /// Figma: Component colors/Components/Icons/Hero Avatar/green-gradient-top 2
  final Color greenGradientTop2;

  /// Figma: Component colors/Components/Icons/Hero Avatar/orange-gradient-bottom
  final Color orangeGradientBottom;

  /// Figma: Component colors/Components/Icons/Hero Avatar/orange-gradient-top
  final Color orangeGradientTop;

  /// Figma: Component colors/Components/Icons/Hero Avatar/purple-gradient-bottom
  final Color purpleGradientBottom;

  /// Figma: Component colors/Components/Icons/Hero Avatar/purple-gradient-top
  final Color purpleGradientTop;

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

  static const light = PregoColors._(
    brightness: Brightness.light,
    // Text
    textBrandPrimary: PregoColorsLight.textBrandPrimary,
    textBrandSecondary: PregoColorsLight.textBrandSecondary,
    textBrandSecondaryHover: PregoColorsLight.textBrandSecondaryHover,
    textBrandTertiary: PregoColorsLight.textBrandTertiary,
    textBrandTertiaryAlt: PregoColorsLight.textBrandTertiaryAlt,
    textDisabled: PregoColorsLight.textDisabled,
    textErrorPrimary: PregoColorsLight.textErrorPrimary,
    textErrorPrimaryHover: PregoColorsLight.textErrorPrimaryHover,
    textPlaceholder: PregoColorsLight.textPlaceholder,
    textPlaceholderSubtle: PregoColorsLight.textPlaceholderSubtle,
    textPrimary: PregoColorsLight.textPrimary,
    textPrimaryOnBrand: PregoColorsLight.textPrimaryOnBrand,
    textPrimaryOnWhite: PregoColorsLight.textPrimaryOnWhite,
    textQuaternary: PregoColorsLight.textQuaternary,
    textQuaternaryOnBrand: PregoColorsLight.textQuaternaryOnBrand,
    textSecondary: PregoColorsLight.textSecondary,
    textSecondaryHover: PregoColorsLight.textSecondaryHover,
    textSecondaryOnBrand: PregoColorsLight.textSecondaryOnBrand,
    textSuccessPrimary: PregoColorsLight.textSuccessPrimary,
    textTertiary: PregoColorsLight.textTertiary,
    textTertiaryHover: PregoColorsLight.textTertiaryHover,
    textTertiaryOnBrand: PregoColorsLight.textTertiaryOnBrand,
    textWarningPrimary: PregoColorsLight.textWarningPrimary,
    textWhite: PregoColorsLight.textWhite,
    // Border
    borderBrand: PregoColorsLight.borderBrand,
    borderBrandAlt: PregoColorsLight.borderBrandAlt,
    borderDisabled: PregoColorsLight.borderDisabled,
    borderDisabledSubtle: PregoColorsLight.borderDisabledSubtle,
    borderError: PregoColorsLight.borderError,
    borderErrorSubtle: PregoColorsLight.borderErrorSubtle,
    borderInsideReversedBottom: PregoColorsLight.borderInsideReversedBottom,
    borderInsideReversedTop: PregoColorsLight.borderInsideReversedTop,
    borderPrimary: PregoColorsLight.borderPrimary,
    borderReversed: PregoColorsLight.borderReversed,
    borderSecondary: PregoColorsLight.borderSecondary,
    borderSecondaryAlt: PregoColorsLight.borderSecondaryAlt,
    borderTertiary: PregoColorsLight.borderTertiary,
    // Foreground
    fgBrandPrimary: PregoColorsLight.fgBrandPrimary,
    fgBrandPrimaryAlt: PregoColorsLight.fgBrandPrimaryAlt,
    fgBrandSecondary: PregoColorsLight.fgBrandSecondary,
    fgBrandSecondaryAlt: PregoColorsLight.fgBrandSecondaryAlt,
    fgBrandSecondaryHover: PregoColorsLight.fgBrandSecondaryHover,
    fgDisabled: PregoColorsLight.fgDisabled,
    fgDisabledSubtle: PregoColorsLight.fgDisabledSubtle,
    fgErrorPrimary: PregoColorsLight.fgErrorPrimary,
    fgErrorSecondary: PregoColorsLight.fgErrorSecondary,
    fgPrimary: PregoColorsLight.fgPrimary,
    fgQuaternary: PregoColorsLight.fgQuaternary,
    fgQuaternaryHover: PregoColorsLight.fgQuaternaryHover,
    fgSecondary: PregoColorsLight.fgSecondary,
    fgSecondaryHover: PregoColorsLight.fgSecondaryHover,
    fgSuccessPrimary: PregoColorsLight.fgSuccessPrimary,
    fgSuccessSecondary: PregoColorsLight.fgSuccessSecondary,
    fgTertiary: PregoColorsLight.fgTertiary,
    fgTertiaryHover: PregoColorsLight.fgTertiaryHover,
    fgWarningPrimary: PregoColorsLight.fgWarningPrimary,
    fgWarningSecondary: PregoColorsLight.fgWarningSecondary,
    fgWhite: PregoColorsLight.fgWhite,
    // Background
    blackWhiteInversed: PregoColorsLight.blackWhiteInversed,
    bgActive: PregoColorsLight.bgActive,
    bgBrandPrimary: PregoColorsLight.bgBrandPrimary,
    bgBrandPrimaryAlt: PregoColorsLight.bgBrandPrimaryAlt,
    bgBrandSecondary: PregoColorsLight.bgBrandSecondary,
    bgBrandSection: PregoColorsLight.bgBrandSection,
    bgBrandSectionSubtle: PregoColorsLight.bgBrandSectionSubtle,
    bgBrandSolid: PregoColorsLight.bgBrandSolid,
    bgBrandSolidHover: PregoColorsLight.bgBrandSolidHover,
    bgBrandHover: PregoColorsLight.bgBrandHover,
    bgBrandPressed: PregoColorsLight.bgBrandPressed,
    bgDestructiveHover: PregoColorsLight.bgDestructiveHover,
    bgDestructivePressed: PregoColorsLight.bgDestructivePressed,
    bgDisabled: PregoColorsLight.bgDisabled,
    bgDisabledSubtle: PregoColorsLight.bgDisabledSubtle,
    bgErrorPrimary: PregoColorsLight.bgErrorPrimary,
    bgErrorSecondary: PregoColorsLight.bgErrorSecondary,
    bgErrorSolid: PregoColorsLight.bgErrorSolid,
    bgErrorSolidHover: PregoColorsLight.bgErrorSolidHover,
    bgGrayHover: PregoColorsLight.bgGrayHover,
    bgGrayPressed: PregoColorsLight.bgGrayPressed,
    bgOverlay: PregoColorsLight.bgOverlay,
    bgPrimary: PregoColorsLight.bgPrimary,
    bgPrimarySolid: PregoColorsLight.bgPrimarySolid,
    bgPrimaryAlt: PregoColorsLight.bgPrimaryAlt,
    bgQuaternary: PregoColorsLight.bgQuaternary,
    bgSecondary: PregoColorsLight.bgSecondary,
    bgSecondarySolid: PregoColorsLight.bgSecondarySolid,
    bgSecondaryAlt: PregoColorsLight.bgSecondaryAlt,
    bgSecondaryHover: PregoColorsLight.bgSecondaryHover,
    bgSecondarySubtle: PregoColorsLight.bgSecondarySubtle,
    bgSuccessPrimary: PregoColorsLight.bgSuccessPrimary,
    bgSuccessSecondary: PregoColorsLight.bgSuccessSecondary,
    bgSuccessSolid: PregoColorsLight.bgSuccessSolid,
    bgTertiary: PregoColorsLight.bgTertiary,
    bgWarningPrimary: PregoColorsLight.bgWarningPrimary,
    bgWarningSecondary: PregoColorsLight.bgWarningSecondary,
    bgWarningSolid: PregoColorsLight.bgWarningSolid,
    bgDestructiveHoverAlt: PregoColorsLight.bgDestructiveHoverAlt,
    bgDestructivePressedAlt: PregoColorsLight.bgDestructivePressedAlt,
    // Effects
    focusRing: PregoColorsLight.focusRing,
    focusRingError: PregoColorsLight.focusRingError,
    // Shadows
    shadow2xl01: PregoColorsLight.shadow2xl01,
    shadow2xl02: PregoColorsLight.shadow2xl02,
    shadow3xl01: PregoColorsLight.shadow3xl01,
    shadow3xl02: PregoColorsLight.shadow3xl02,
    shadowInversed: PregoColorsLight.shadowInversed,
    shadowLg01: PregoColorsLight.shadowLg01,
    shadowLg02: PregoColorsLight.shadowLg02,
    shadowLg03: PregoColorsLight.shadowLg03,
    shadowMd01: PregoColorsLight.shadowMd01,
    shadowMd02: PregoColorsLight.shadowMd02,
    skeuomorphicShadow: PregoColorsLight.skeuomorphicShadow,
    skeuomorphicInnerBorder: PregoColorsLight.skeuomorphicInnerBorder,
    shadowSm01: PregoColorsLight.shadowSm01,
    shadowSm02: PregoColorsLight.shadowSm02,
    shadowXl01: PregoColorsLight.shadowXl01,
    shadowXl02: PregoColorsLight.shadowXl02,
    shadowXl03: PregoColorsLight.shadowXl03,
    shadowXs: PregoColorsLight.shadowXs,
    // Buttons
    buttonDestructivePrimaryIcon: PregoColorsLight.buttonDestructivePrimaryIcon,
    buttonDestructivePrimaryIconHover: PregoColorsLight.buttonDestructivePrimaryIconHover,
    buttonGlassPrimaryBackground: PregoColorsLight.buttonGlassPrimaryBackground,
    buttonGlassPrimaryHover: PregoColorsLight.buttonGlassPrimaryHover,
    buttonPrimaryIcon: PregoColorsLight.buttonPrimaryIcon,
    buttonPrimaryIconHover: PregoColorsLight.buttonPrimaryIconHover,
    // Icons
    iconFgBrand: PregoColorsLight.iconFgBrand,
    iconFgBrandOnBrand: PregoColorsLight.iconFgBrandOnBrand,
    // Alpha
    alphaBlack10: PregoColorsLight.alphaBlack10,
    alphaBlack20: PregoColorsLight.alphaBlack20,
    alphaBlack30: PregoColorsLight.alphaBlack30,
    alphaBlack40: PregoColorsLight.alphaBlack40,
    alphaBlack50: PregoColorsLight.alphaBlack50,
    alphaBlack60: PregoColorsLight.alphaBlack60,
    alphaBlack70: PregoColorsLight.alphaBlack70,
    alphaBlack80: PregoColorsLight.alphaBlack80,
    alphaBlack90: PregoColorsLight.alphaBlack90,
    alphaBlack100: PregoColorsLight.alphaBlack100,
    alphaWhite10: PregoColorsLight.alphaWhite10,
    alphaWhite20: PregoColorsLight.alphaWhite20,
    alphaWhite30: PregoColorsLight.alphaWhite30,
    alphaWhite40: PregoColorsLight.alphaWhite40,
    alphaWhite50: PregoColorsLight.alphaWhite50,
    alphaWhite60: PregoColorsLight.alphaWhite60,
    alphaWhite70: PregoColorsLight.alphaWhite70,
    alphaWhite80: PregoColorsLight.alphaWhite80,
    alphaWhite90: PregoColorsLight.alphaWhite90,
    alphaWhite100: PregoColorsLight.alphaWhite100,
    // Utility
    utilityBlue50: PregoColorsLight.utilityBlue50,
    utilityBlue100: PregoColorsLight.utilityBlue100,
    utilityBlue200: PregoColorsLight.utilityBlue200,
    utilityBlue300: PregoColorsLight.utilityBlue300,
    utilityBlue400: PregoColorsLight.utilityBlue400,
    utilityBlue500: PregoColorsLight.utilityBlue500,
    utilityBlue600: PregoColorsLight.utilityBlue600,
    utilityBlue700: PregoColorsLight.utilityBlue700,
    utilityError50: PregoColorsLight.utilityError50,
    utilityError100: PregoColorsLight.utilityError100,
    utilityError200: PregoColorsLight.utilityError200,
    utilityError300: PregoColorsLight.utilityError300,
    utilityError400: PregoColorsLight.utilityError400,
    utilityError500: PregoColorsLight.utilityError500,
    utilityError600: PregoColorsLight.utilityError600,
    utilityError700: PregoColorsLight.utilityError700,
    utilitySuccess50: PregoColorsLight.utilitySuccess50,
    utilitySuccess100: PregoColorsLight.utilitySuccess100,
    utilitySuccess200: PregoColorsLight.utilitySuccess200,
    utilitySuccess300: PregoColorsLight.utilitySuccess300,
    utilitySuccess400: PregoColorsLight.utilitySuccess400,
    utilitySuccess500: PregoColorsLight.utilitySuccess500,
    utilitySuccess600: PregoColorsLight.utilitySuccess600,
    utilitySuccess700: PregoColorsLight.utilitySuccess700,
    utilityWarning50: PregoColorsLight.utilityWarning50,
    utilityWarning100: PregoColorsLight.utilityWarning100,
    utilityWarning200: PregoColorsLight.utilityWarning200,
    utilityWarning300: PregoColorsLight.utilityWarning300,
    utilityWarning400: PregoColorsLight.utilityWarning400,
    utilityWarning500: PregoColorsLight.utilityWarning500,
    utilityWarning600: PregoColorsLight.utilityWarning600,
    utilityWarning700: PregoColorsLight.utilityWarning700,
    // Other
    avatarStylesBgNeutral: PregoColorsLight.avatarStylesBgNeutral,
    brandGradientBottom: PregoColorsLight.brandGradientBottom,
    brandGradientTop: PregoColorsLight.brandGradientTop,
    featuredIconLightFgBrand: PregoColorsLight.featuredIconLightFgBrand,
    featuredIconLightFgError: PregoColorsLight.featuredIconLightFgError,
    featuredIconLightFgGray: PregoColorsLight.featuredIconLightFgGray,
    featuredIconLightFgSuccess: PregoColorsLight.featuredIconLightFgSuccess,
    featuredIconLightFgWarning: PregoColorsLight.featuredIconLightFgWarning,
    greenGradientBottom: PregoColorsLight.greenGradientBottom,
    greenGradientTop2: PregoColorsLight.greenGradientTop2,
    orangeGradientBottom: PregoColorsLight.orangeGradientBottom,
    orangeGradientTop: PregoColorsLight.orangeGradientTop,
    purpleGradientBottom: PregoColorsLight.purpleGradientBottom,
    purpleGradientTop: PregoColorsLight.purpleGradientTop,
    toggleBorder: PregoColorsLight.toggleBorder,
    toggleButtonFgDisabled: PregoColorsLight.toggleButtonFgDisabled,
    toggleSlimBorderPressed: PregoColorsLight.toggleSlimBorderPressed,
    toggleSlimBorderPressedHover: PregoColorsLight.toggleSlimBorderPressedHover,
  );

  static PregoColors lerpColors({required PregoColors a, required PregoColors b, required double t}) => PregoColors._(
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
    brandGradientBottom: lerpColorNonNull(a.brandGradientBottom, b.brandGradientBottom, t),
    brandGradientTop: lerpColorNonNull(a.brandGradientTop, b.brandGradientTop, t),
    featuredIconLightFgBrand: lerpColorNonNull(a.featuredIconLightFgBrand, b.featuredIconLightFgBrand, t),
    featuredIconLightFgError: lerpColorNonNull(a.featuredIconLightFgError, b.featuredIconLightFgError, t),
    featuredIconLightFgGray: lerpColorNonNull(a.featuredIconLightFgGray, b.featuredIconLightFgGray, t),
    featuredIconLightFgSuccess: lerpColorNonNull(a.featuredIconLightFgSuccess, b.featuredIconLightFgSuccess, t),
    featuredIconLightFgWarning: lerpColorNonNull(a.featuredIconLightFgWarning, b.featuredIconLightFgWarning, t),
    greenGradientBottom: lerpColorNonNull(a.greenGradientBottom, b.greenGradientBottom, t),
    greenGradientTop2: lerpColorNonNull(a.greenGradientTop2, b.greenGradientTop2, t),
    orangeGradientBottom: lerpColorNonNull(a.orangeGradientBottom, b.orangeGradientBottom, t),
    orangeGradientTop: lerpColorNonNull(a.orangeGradientTop, b.orangeGradientTop, t),
    purpleGradientBottom: lerpColorNonNull(a.purpleGradientBottom, b.purpleGradientBottom, t),
    purpleGradientTop: lerpColorNonNull(a.purpleGradientTop, b.purpleGradientTop, t),
    toggleBorder: lerpColorNonNull(a.toggleBorder, b.toggleBorder, t),
    toggleButtonFgDisabled: lerpColorNonNull(a.toggleButtonFgDisabled, b.toggleButtonFgDisabled, t),
    toggleSlimBorderPressed: lerpColorNonNull(a.toggleSlimBorderPressed, b.toggleSlimBorderPressed, t),
    toggleSlimBorderPressedHover: lerpColorNonNull(a.toggleSlimBorderPressedHover, b.toggleSlimBorderPressedHover, t),
  );
}
