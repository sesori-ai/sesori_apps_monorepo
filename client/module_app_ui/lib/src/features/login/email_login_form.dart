import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../extensions/login_failed_reason_x.dart";

/// Vertical gap between the email and password fields (Figma).
const double _fieldGap = 22.0;

/// Vertical gap between the field group and the submit button (Figma).
const double _submitGap = 30.0;

/// Email and password sign-in form, shared by every shell.
///
/// Reads the [LoginCubit] from context. The form owns its failure surface: a
/// failed sign-in renders inline, next to the fields that caused it. The host
/// decides what a successful sign-in does to its surroundings through
/// [onSignedIn], called after the platform is offered the credentials to save.
class const EmailLoginForm({
  super.key,
  required final VoidCallback onSignedIn,
}) extends StatefulWidget {
  @override
  State<EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState() extends State<EmailLoginForm> {
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

    final success = await context.read<LoginCubit>().loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (!success) return;

    // Let the platform offer to save the credentials, then hand over to the host.
    TextInput.finishAutofillContext();
    widget.onSignedIn();
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
                supportingText: state.reason.localizedMessage(loc: loc),
                type: PregoInlineAlertsNotificationsType.error,
              ),
              const SizedBox(height: _fieldGap),
            ],
            PregoInputField(
              controller: _emailController,
              label: loc.emailLabel,
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
              // matching the provider buttons beside the form.
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              isLoading: isLoading,
              fullWidth: true,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Eye toggle inside the password field.
class const _PasswordVisibilityToggle({
  required final bool isObscured,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Semantics(
      button: true,
      label: isObscured ? loc.passwordShow : loc.passwordHide,
      child: GestureDetector(
        onTap: onPressed,
        // Fill the field's trailing slot so the whole minimum-size touch target
        // is tappable, not just the 14pt glyph.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: PregoInputField.trailingSlotSize,
          height: PregoInputField.trailingSlotSize,
          child: Center(
            child: Icon(
              isObscured ? TablerRegular.eye_off : TablerRegular.eye,
              size: PregoIconSize.sm,
              color: context.prego.colors.fgQuaternary,
            ),
          ),
        ),
      ),
    );
  }
}
