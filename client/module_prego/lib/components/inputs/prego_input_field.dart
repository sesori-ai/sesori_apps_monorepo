/// Labelled text input from the Figma "Input Field" component.
///
/// A pill-shaped field on `bg-surface-3` with an external label above it —
/// unlike Material's floating label, the label never moves into the border, so
/// the field keeps a constant height whether or not it holds text.
library;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../theme/prego_theme.dart";

/// Horizontal padding inside the pill. Between [PregoSpacing.lg] and
/// [PregoSpacing.xl]; the Figma component specifies 14 and there is no token
/// for it.
const double _inputHorizontalPadding = 14.0;

/// Vertical padding inside the pill. With the `text-md` line height (24) this
/// gives the 44pt field height the design specifies.
const double _inputVerticalPadding = 10.0;

/// Square trailing slot, sized to the platform minimum touch target. A 16pt
/// glyph centred in it lands exactly [_inputHorizontalPadding] + half a glyph
/// from the field's trailing edge, matching the design.
const double _trailingSlotSize = 44.0;

/// A labelled, pill-shaped text field.
///
/// The label sits above the field and carries an optional brand-coloured
/// asterisk when [isRequired]. Validation follows the standard [FormField]
/// contract: supply a [validator] and drive it from an enclosing [Form], and
/// the message renders below the pill with the border switched to
/// `border-error`.
///
/// Usage:
/// ```dart
/// PregoInputField(
///   controller: _emailController,
///   label: loc.emailLabel,
///   isRequired: true,
///   keyboardType: TextInputType.emailAddress,
///   validator: _validateEmail,
/// )
/// ```
class PregoInputField extends StatelessWidget {
  const PregoInputField({
    super.key,
    required this.controller,
    required this.label,
    this.isRequired = false,
    this.hintText,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.focusNode,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
  });

  /// Holds the field's text. The caller owns its lifecycle.
  final TextEditingController controller;

  /// Label rendered above the field.
  final String label;

  /// Whether to append a brand-coloured `*` to [label]. Purely presentational —
  /// enforce the requirement in [validator].
  final bool isRequired;

  /// Placeholder shown while the field is empty.
  final String? hintText;

  /// When false the field rejects input and dims to the disabled palette.
  final bool enabled;

  /// Whether to hide the text (passwords). Pair with a [trailing] toggle.
  final bool obscureText;

  final bool autocorrect;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  /// Returns an error message, or null when the value is valid. Runs on
  /// [FormState.validate] and re-runs as the user edits once it has failed.
  final String? Function(String? value)? validator;

  /// Invoked when the user submits from the keyboard.
  final void Function(String value)? onSubmitted;

  final void Function(String value)? onChanged;

  /// Widget in the trailing slot inside the pill, e.g. a visibility toggle.
  ///
  /// Interactive content should fill [trailingSlotSize] square and carry its own
  /// gesture handling and semantics, so the whole touch target responds rather
  /// than just the glyph.
  final Widget? trailing;

  /// Edge length of the [trailing] slot. Interactive trailing content should
  /// size itself to this so it meets the minimum touch target.
  static const double trailingSlotSize = _trailingSlotSize;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final labelStyle = prego.textTheme.textSm.medium.copyWith(color: colors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The asterisk is decoration; `Text.rich` keeps label and marker in one
        // semantics node so screen readers announce "Email *" as the field's
        // label rather than two stray fragments.
        Text.rich(
          TextSpan(
            text: label,
            style: labelStyle,
            children: isRequired
                ? [
                    TextSpan(
                      text: " *",
                      style: prego.textTheme.textSm.bold.copyWith(
                        color: colors.textBrandTertiary,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: PregoSpacing.sm),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          autocorrect: autocorrect,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          focusNode: focusNode,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          // Re-validate as the user fixes a rejected value, but don't scold
          // them mid-typing before the first submit.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: prego.textTheme.textMd.regular.copyWith(color: colors.textPrimary),
          cursorColor: colors.borderBrand,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: prego.textTheme.textMd.regular.copyWith(
              color: colors.textPlaceholder,
            ),
            filled: true,
            fillColor: enabled ? colors.bgSurface3 : colors.bgDisabledSubtle,
            isDense: true,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: _inputHorizontalPadding,
              vertical: _inputVerticalPadding,
            ),
            suffixIcon: trailing,
            // Reserve the full touch target rather than Material's 48pt suffix
            // minimum, which would stretch the pill past its 44pt height.
            suffixIconConstraints: const BoxConstraints(
              minWidth: _trailingSlotSize,
              minHeight: _trailingSlotSize,
            ),
            enabledBorder: _border(colors.borderPrimary),
            focusedBorder: _border(colors.borderBrand),
            errorBorder: _border(colors.borderError),
            focusedErrorBorder: _border(colors.borderError),
            disabledBorder: _border(colors.borderDisabled),
            errorStyle: prego.textTheme.textSm.regular.copyWith(
              color: colors.textErrorPrimary,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(PregoRadius.full),
    borderSide: BorderSide(color: color),
  );
}
