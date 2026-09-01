import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";

/// Mobile-only notification-preference composition for the shared view.
class const NotificationSettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationPreferencesCubit(
        service: getIt<NotificationPreferencesService>(),
      ),
      child: NotificationSettingsView(
        connectionBanner: ConnectionBanner.maybeFor(context),
        onClose: () => context.goRoute(const AppRoute.projects()),
      ),
    );
  }
}
