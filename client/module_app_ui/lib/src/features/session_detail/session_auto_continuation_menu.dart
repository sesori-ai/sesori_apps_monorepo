import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// Shared by the phone's glass bar and desktop's page toolbar.
PregoMenuItem sessionAutoContinuationMenuEntry({required BuildContext context, required Session session}) {
  final view = session.autoContinuation;
  final enabled = view?.enabled ?? false;
  final state = context.read<SessionDetailCubit>().state;
  final canInteract = switch (state) {
    SessionDetailLoaded(:final interaction) ||
    SessionDetailHarnessUnavailable(:final interaction) => interaction.canInteract,
    SessionDetailLoading() || SessionDetailFailed() => false,
  };
  final available = view?.availability == AutoContinuationAvailability.conditional && canInteract;
  final updating = state.autoContinuationUpdatePending;
  return PregoMenuItem(
    key: const Key("session-auto-continuation-toggle"),
    title: context.loc.sessionAutoContinuationMenu,
    subtitle: available
        ? context.loc.sessionAutoContinuationAfterQuotaResets
        : view == null
        ? context.loc.sessionAutoContinuationOlderBridge
        : context.loc.sessionAutoContinuationUnavailable,
    leadingIcon: TablerRegular.clock,
    isSelected: enabled,
    isEnabled: !updating && (enabled || available),
    shortcutLabel: null,
    onTap: () => unawaited(context.read<SessionDetailCubit>().setAutoContinuation(enabled: !enabled)),
  );
}
