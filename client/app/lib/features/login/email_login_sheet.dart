import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

/// Presents the "Sign in with Email" bottom sheet hosting the shared
/// [EmailLoginForm].
///
/// The [cubit] is passed explicitly: the sheet is a sibling modal route, so it
/// cannot read the [LoginCubit] the login screen provides through the tree.
///
/// The form renders failures inline, and the login screen stands its banner
/// down while the sheet is open so the same error isn't shown twice. Any
/// lingering failure is cleared both on open and on dismiss so the banner
/// doesn't surface it afterwards.
Future<void> showEmailLoginSheet({
  required BuildContext context,
  required LoginCubit cubit,
}) async {
  // A failed provider sign-in leaves the shared cubit in LoginFailed. Since the
  // form renders failures inline, clear any pre-existing failure before opening
  // so a stale provider error (e.g. a browser or Apple failure) isn't surfaced
  // next to the email fields before the user has even submitted. While the sheet
  // is up only the email form can fail, so the inline alert only ever reflects
  // an email attempt.
  cubit.onDismissedLoginFailureError();
  await showPregoModal<void>(
    context: context,
    title: context.loc.signInWithEmail,
    builder: (sheetContext) => BlocProvider<LoginCubit>.value(
      value: cubit,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: EmailLoginForm(
          // On success the login screen's listener navigates to the projects
          // route, which can tear this modal down. Only pop while this sheet is
          // still the route on top, so the pop closes this sheet and not that
          // route.
          onSignedIn: () {
            if (ModalRoute.of(sheetContext)?.isCurrent ?? false) sheetContext.pop();
          },
          // The sheet's own close control leads back to the other options.
          onBack: null,
        ),
      ),
    ),
  );
  // A successful sign-in navigates away and disposes the screen that owns the
  // cubit, so it may already be closed by the time the sheet's route settles.
  if (!cubit.isClosed) cubit.onDismissedLoginFailureError();
}
