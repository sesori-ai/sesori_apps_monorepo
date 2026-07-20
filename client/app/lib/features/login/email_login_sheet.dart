import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/login_failed_reason_x.dart";

/// Vertical gap between the email and password fields (Figma).
const double _fieldGap = 22.0;

/// Vertical gap between the field group and the submit button (Figma).
const double _submitGap = 30.0;

/// Presents the "Sign in with Email" bottom sheet.
///
/// The [cubit] is passed explicitly: the sheet is a sibling modal route, so it
/// cannot read the [LoginCubit] the login screen provides through the tree.
///
/// The sheet owns its own failure surface: a failed sign-in renders inline,
/// next to the form that caused it, and the login screen stands its banner down
/// while the sheet is open so the same error isn't shown twice. Any lingering
/// failure is cleared on dismiss so the banner doesn't surface it afterwards.
Future<void> showEmailLoginSheet({
  required BuildContext context,
  required LoginCubit cubit,
}) async {
  await showPregoBottomSheet<void>(
    context: context,
    title: context.loc.signInWithEmail,
    builder: (_) => BlocProvider<LoginCubit>.value(
      value: cubit,
      child: const EmailLoginSheet(),
    ),
  );
  // A successful sign-in navigates away and disposes the screen that owns the
  // cubit, so it may already be closed by the time the sheet's route settles.
  if (!cubit.isClosed) cubit.onDismissedLoginFailureError();
}

@visibleForTesting
class EmailLoginSheet extends StatefulWidget {
  const EmailLoginSheet({super.key});

  @override
  State<EmailLoginSheet> createState() => _EmailLoginSheetState();
}

class _EmailLoginSheetState extends State<EmailLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final loc = context.loc;
    final email = value?.trim() ?? "";
    if (email.isEmpty) return loc.emailRequired;
    // Deliberately permissive: the auth server is the authority on whether an
    // address exists. This only catches obvious typos before a round-trip.
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
      return loc.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return context.loc.passwordRequired;
    return null;
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) {
      loge("Email login form state is null");
      context.read<LoginCubit>().onMissingFormKey();
      return;
    }
    if (!formState.validate()) return;

    // Captured before the await: on success the login screen's listener
    // navigates to the projects route, which can tear this modal down. Popping
    // the navigator blindly afterwards would then pop *that* route instead, so
    // only pop while this sheet is still the route on top.
    final navigator = Navigator.of(context);
    final sheetRoute = ModalRoute.of(context);

    final success = await context.read<LoginCubit>().loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (!success) return;

    // Let the platform offer to save the credentials, then close the sheet.
    TextInput.finishAutofillContext();
    if (sheetRoute?.isCurrent ?? false) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<LoginCubit>().state;
    final isLoading = state is LoginAuthenticating;

    return AutofillGroup(
      // Disposing the group would otherwise commit the autofill context and
      // prompt "Save Password?" even when the sign-in was rejected. Cancel on
      // dispose; _submit commits explicitly, only after the server accepts.
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state is LoginFailed) ...[
              PregoInlineAlertsNotifications(
                title: loc.loginAuthenticationFailedTitle,
                supportingText: state.reason.localizedMessage(loc),
                type: PregoInlineAlertsNotificationsType.error,
              ),
              const SizedBox(height: _fieldGap),
            ],
            PregoInputField(
              controller: _emailController,
              label: loc.emailLabel,
              isRequired: true,
              hintText: loc.emailHint,
              enabled: !isLoading,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              validator: _validateEmail,
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: _fieldGap),
            PregoInputField(
              controller: _passwordController,
              label: loc.passwordLabel,
              isRequired: true,
              enabled: !isLoading,
              obscureText: _obscurePassword,
              autocorrect: false,
              focusNode: _passwordFocusNode,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: _validatePassword,
              onSubmitted: (_) => _submit(),
              trailing: _PasswordVisibilityToggle(
                isObscured: _obscurePassword,
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: _submitGap),
            PregoButtonsSolid(
              label: loc.signIn,
              // `primaryAlt` is the fg-primary (900) fill the design specifies,
              // matching the provider buttons on the login screen behind it.
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              isLoading: isLoading,
              fullWidth: true,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: PregoSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Eye toggle inside the password field.
class _PasswordVisibilityToggle extends StatelessWidget {
  const _PasswordVisibilityToggle({
    required this.isObscured,
    required this.onPressed,
  });

  final bool isObscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Semantics(
      button: true,
      label: isObscured ? loc.passwordShow : loc.passwordHide,
      child: GestureDetector(
        onTap: onPressed,
        // Fill the field's trailing slot so the whole minimum-size touch target
        // is tappable, not just the 16pt glyph.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: PregoInputField.trailingSlotSize,
          height: PregoInputField.trailingSlotSize,
          child: Center(
            child: Icon(
              isObscured ? TablerRegular.eye_off : TablerRegular.eye,
              size: 16,
              color: context.prego.colors.fgQuaternary,
            ),
          ),
        ),
      ),
    );
  }
}
