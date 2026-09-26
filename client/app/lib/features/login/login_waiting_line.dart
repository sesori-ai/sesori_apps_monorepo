import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

/// The line under the provider buttons while a browser sign-in waits. It always
/// offers Cancel, because the provider buttons stay disabled until the attempt
/// ends, and says so when the browser did not open.
class const LoginWaitingLine({super.key, required final LoginBrowserLaunch browser}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Column(
        mainAxisSize: .min,
        children: [
          Text(
            switch (browser) {
              LoginBrowserLaunch.opened => loc.loginPolling,
              LoginBrowserLaunch.failed => loc.loginBrowserOpenFailed,
            },
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          PregoButtonsSolid(
            label: loc.loginCancel,
            hierarchy: PregoButtonsSolidHierarchy.link,
            size: PregoButtonsSolidSize.sm,
            onPressed: () => unawaited(context.read<LoginCubit>().cancel()),
          ),
        ],
      ),
    );
  }
}
