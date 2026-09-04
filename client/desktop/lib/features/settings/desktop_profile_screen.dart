import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "../../core/di/injection.dart";

/// Desktop-shell composition for the shared profile view.
class const DesktopProfileScreen({
  super.key,
  required final VoidCallback onClose,
  required final VoidCallback onLogoutCompleted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductAnalyticsPreferenceCubit(service: getIt<ProductAnalyticsService>()),
      child: _DesktopProfileView(
        onClose: onClose,
        onLogoutCompleted: onLogoutCompleted,
      ),
    );
  }
}

class const _DesktopProfileView({
  required final VoidCallback onClose,
  required final VoidCallback onLogoutCompleted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthGateCubit authGateCubit = context.read<AuthGateCubit>();
    final AuthUser? account = switch (context.watch<AuthGateCubit>().state) {
      AuthGateSignedIn(:final user) => user,
      AuthGateChecking() || AuthGateSignedOut() => null,
    };

    return ProfileView(
      account: account,
      connectionBanner: null,
      onClose: onClose,
      logout: () async {
        final outcome = await authGateCubit.signOut();
        if (outcome != DesktopLogoutOutcome.completed) return false;
        onLogoutCompleted();
        return true;
      },
    );
  }
}
