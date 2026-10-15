import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "../settings/widgets/settings_section.dart";
import "mcp_server_controls_view.dart";

/// Shells supply composition; the shared presentation never resolves DI.
Future<void> showMcpInventory({
  required BuildContext context,
  required McpInventoryRequest request,
  required McpService Function() createService,
  required McpAuthenticationService Function() authenticationService,
  required bool mutationsAllowed,
}) async {
  await showPregoModal<void>(
    context: context,
    title: context.loc.mcpTitle,
    width: PregoModalWidth.browser,
    bodySize: PregoBottomSheetBodySize.seventyPercent,
    builder: (_) {
      final service = createService();
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => McpCubit(service: service, request: request, mutationsAllowed: mutationsAllowed),
          ),
          BlocProvider(create: (_) => McpActionCubit(service: service)),
          BlocProvider(create: (_) => McpAuthenticationCubit(service: authenticationService())),
        ],
        child: const McpInventoryView(),
      );
    },
  );
}

class const McpInventoryView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<McpCubit>();
    final state = cubit.state;
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InventoryHeader(action: context.watch<McpActionCubit>().state),
        Expanded(
          child: switch (state) {
            McpInventoryReady(:final McpInventorySnapshot inventory) => _Catalog(inventory: inventory),
            McpInventoryReady(:final McpInventoryUnavailable inventory) => _Message(
              message: _unavailable(reason: inventory.reason, loc: loc),
            ),
            McpInventoryReady(inventory: McpInventoryUnknown()) => _Message(message: loc.mcpUnknownResponse),
            McpInventoryInitial() || McpInventoryLoading() => const Center(child: PregoActivityIndicator(color: null)),
            McpInventoryWaitingForConnection() => _Message(message: loc.mcpWaiting),
            McpInventoryNotFound() => _Message(message: loc.mcpNotFound),
            McpInventoryUnrecognized() => _Message(message: loc.mcpUnknownResponse),
            McpInventoryReadFailed() || McpInventoryFailed() => _Message(message: loc.mcpReadFailed),
          },
        ),
      ],
    );
  }
}

class const _InventoryHeader({required final McpActionClientState action}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<McpCubit>();
    final state = cubit.state;
    final loc = context.loc;
    final actionMessage = switch (action) {
      McpActionPending(request: McpEntryActionRequest(action: McpConnectorSetupEntryAction())) => loc.mcpSetupOpening,
      McpConnectorSetupOpened() => loc.mcpSetupOpened,
      McpConnectorSetupFailed() => loc.mcpSetupOpenFailed,
      McpActionReceivedState(request: McpEntryActionRequest(action: McpConnectorSetupEntryAction()), :final result) =>
        switch (result) {
          McpActionUnavailable(:final reason) => switch (reason) {
            McpActionUnavailableReason.nativeConfigurationRequired => loc.mcpSetupInHarness,
            McpActionUnavailableReason.targetNotFound => loc.mcpOfferNotFound,
            McpActionUnavailableReason.unsupportedHarness => loc.mcpUnsupportedHarness,
            McpActionUnavailableReason.unsupportedScope => loc.mcpUnsupportedScope,
            McpActionUnavailableReason.liveSessionRequired => loc.mcpLiveSessionRequired,
            McpActionUnavailableReason.pluginInactive => loc.mcpPluginInactive,
            _ => loc.mcpSetupOpenFailed,
          },
          _ => loc.mcpSetupOpenFailed,
        },
      _ => null,
    };
    // This fixed slot changes independently of either reader's scroll area.
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(64),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                child: Text(
                  actionMessage ?? _status(state: state, loc: loc),
                  key: ValueKey(actionMessage ?? _status(state: state, loc: loc)),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: PregoSpacing.sm),
          PregoButtonsSolid(
            label: loc.mcpRefresh,
            leadingIcon: TablerRegular.refresh,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed:
                state is McpInventoryLoading ||
                    state is McpInventoryWaitingForConnection ||
                    state is McpInventoryReady &&
                        (state.refresh is McpInventoryRefreshing || state.refresh is McpInventoryRefreshOffline)
                ? null
                : cubit.refresh,
          ),
        ],
      ),
    );
  }
}

String _status({required McpInventoryState state, required AppLocalizations loc}) => switch (state) {
  McpInventoryReady(:final refresh) => switch (refresh) {
    McpInventoryRefreshIdle() => loc.mcpInventoryReady,
    McpInventoryRefreshing() => loc.mcpRefreshing,
    McpInventoryRefreshOffline() => loc.mcpOffline,
    McpInventoryRefreshUnrecognized() => loc.mcpRefreshUnrecognized,
    McpInventoryRefreshNotFound() => loc.mcpRefreshNotFound,
    McpInventoryRefreshFailed() || McpInventoryRefreshUnavailable() => loc.mcpRefreshFailed,
  },
  McpInventoryInitial() || McpInventoryLoading() => loc.mcpLoading,
  McpInventoryWaitingForConnection() => loc.mcpWaiting,
  McpInventoryUnrecognized() => loc.mcpUnknownResponse,
  McpInventoryNotFound() || McpInventoryReadFailed() || McpInventoryFailed() => loc.mcpReadFailed,
};

String _unavailable({required McpInventoryUnavailableReason reason, required AppLocalizations loc}) => switch (reason) {
  McpInventoryUnavailableReason.unknown => loc.mcpUnavailable,
  McpInventoryUnavailableReason.unsupportedHarness => loc.mcpUnsupportedHarness,
  McpInventoryUnavailableReason.unsupportedScope => loc.mcpUnsupportedScope,
  McpInventoryUnavailableReason.liveSessionRequired => loc.mcpLiveSessionRequired,
  McpInventoryUnavailableReason.pluginInactive => loc.mcpPluginInactive,
  McpInventoryUnavailableReason.readFailed => loc.mcpReadFailed,
};

class const _Catalog({required final McpInventorySnapshot inventory}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final hasUnknownEntries = inventory.entries.any((entry) => entry is McpUnknownInventoryEntry);
    return ListView(
      key: const PageStorageKey("mcp_inventory"),
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      children: [
        _Section(
          title: loc.mcpServers,
          availability: inventory.servers,
          hasUnknownEntries: hasUnknownEntries,
          entries: inventory.entries
              .whereType<McpServerSnapshot>()
              .map(
                (server) => PregoGroupedRow(
                  key: ValueKey(server.serverTarget),
                  title: Text(server.name),
                  subtitle: Text(_connection(connection: server.connection, loc: loc)),
                  trailing: const Icon(TablerRegular.chevron_right, size: PregoIconSize.sm),
                  onTap: () => _showServer(context: context, target: server.serverTarget),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: PregoSpacing.xl),
        _Section(
          title: loc.mcpConnectors,
          availability: inventory.connectors,
          hasUnknownEntries: hasUnknownEntries,
          entries: inventory.entries
              .whereType<McpConnectorOfferSnapshot>()
              .map(
                (offer) => LayoutBuilder(
                  key: ValueKey(offer.offerTarget),
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < MediaQuery.textScalerOf(context).scale(440);
                    final button = offer.actions.contains(McpConnectorAction.setup)
                        ? _SetupButton(target: offer.offerTarget, fullWidth: stacked)
                        : null;
                    final status = switch (offer.availability) {
                      McpConnectorOfferAvailability.unknown => loc.mcpUnknown,
                      McpConnectorOfferAvailability.available => loc.mcpOfferAvailable,
                      McpConnectorOfferAvailability.setupRequired
                          when !offer.actions.contains(McpConnectorAction.setup) =>
                        loc.mcpSetupInHarness,
                      McpConnectorOfferAvailability.setupRequired => loc.mcpSetupRequired,
                      McpConnectorOfferAvailability.unavailable => loc.mcpUnavailable,
                    };
                    return AnimatedSize(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      alignment: Alignment.topCenter,
                      child: PregoGroupedRow(
                        title: Text(offer.name),
                        subtitle: stacked && button != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(status),
                                  const SizedBox(height: PregoSpacing.md),
                                  button,
                                ],
                              )
                            : Text(status),
                        trailing: stacked ? null : button,
                      ),
                    );
                  },
                ),
              )
              .toList(growable: false),
        ),
        if (hasUnknownEntries)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: PregoSpacing.md),
            child: Text(loc.mcpUnknownResponse),
          ),
      ],
    );
  }
}

class const _SetupButton({required final McpConnectorOfferTarget target, required final bool fullWidth})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<McpCubit>();
    final actions = context.watch<McpActionCubit>();
    final state = inventory.state;
    final blocked =
        !inventory.mutationsAllowed ||
        state is! McpInventoryReady ||
        state.refresh is McpInventoryRefreshOffline ||
        actions.state is McpActionPending ||
        actions.state is McpActionsReadOnly ||
        actions.state is McpActionOffline;
    return PregoButtonsSolid(
      label: context.loc.mcpOpenSetup,
      leadingIcon: TablerRegular.external_link,
      hierarchy: PregoButtonsSolidHierarchy.secondary,
      size: PregoButtonsSolidSize.sm,
      fullWidth: fullWidth,
      onPressed: blocked ? null : () => actions.execute(action: McpConnectorSetupEntryAction(offerTarget: target)),
    );
  }
}

class const _Section({
  required final String title,
  required final McpCatalogAvailability availability,
  required final List<Widget> entries,
  required final bool hasUnknownEntries,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return SettingsSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isNotEmpty) PregoGroupedRows(color: context.prego.colors.bgSurface2, children: entries),
          if (availability is! McpCatalogAvailable || entries.isEmpty && !hasUnknownEntries)
            Padding(
              padding: const EdgeInsets.all(PregoSpacing.md),
              child: Text(switch (availability) {
                McpCatalogAvailable() => loc.mcpEmptyCatalog,
                McpCatalogNotSupported() => loc.mcpCatalogNotSupported,
                McpCatalogUnavailable() => loc.mcpCatalogUnavailable,
                McpCatalogUnknown() => loc.mcpUnknownResponse,
              }),
            ),
        ],
      ),
    );
  }
}

Future<void> _showServer({required BuildContext context, required McpServerTarget target}) async {
  final cubit = context.read<McpCubit>();
  await showPregoModal<void>(
    context: context,
    title: context.loc.mcpServerDetails,
    width: PregoModalWidth.browser,
    bodySize: PregoBottomSheetBodySize.seventyPercent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ServerDetails(
        target: target,
        onManage: cubit.mutationsAllowed ? () => showMcpServerControls(context: context, target: target) : null,
      ),
    ),
  );
}

class const _ServerDetails({required final McpServerTarget target, required final VoidCallback? onManage})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<McpCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InventoryHeader(action: McpActionIdle()),
        Expanded(
          child: _details(context: context, state: state),
        ),
        if (onManage case final manage?)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: PregoSpacing.md),
            child: PregoButtonsSolid(
              label: context.loc.mcpManageConnection,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.md,
              fullWidth: true,
              onPressed: manage,
            ),
          ),
      ],
    );
  }

  Widget _details({required BuildContext context, required McpInventoryState state}) {
    final inventory = switch (state) {
      McpInventoryReady(:final McpInventorySnapshot inventory) => inventory,
      McpInventoryReady() ||
      McpInventoryInitial() ||
      McpInventoryWaitingForConnection() ||
      McpInventoryLoading() ||
      McpInventoryUnrecognized() ||
      McpInventoryNotFound() ||
      McpInventoryReadFailed() ||
      McpInventoryFailed() => null,
    };
    final server = inventory?.entries
        .whereType<McpServerSnapshot>()
        .where((entry) => entry.serverTarget == target)
        .firstOrNull;
    final loc = context.loc;
    if (server == null) {
      return _Message(
        message: switch (state) {
          McpInventoryReady(inventory: McpInventorySnapshot()) => loc.mcpServerNotFound,
          McpInventoryReady(:final McpInventoryUnavailable inventory) => _unavailable(
            reason: inventory.reason,
            loc: loc,
          ),
          McpInventoryReady(inventory: McpInventoryUnknown()) || McpInventoryUnrecognized() => loc.mcpUnknownResponse,
          McpInventoryInitial() || McpInventoryLoading() => loc.mcpLoading,
          McpInventoryWaitingForConnection() => loc.mcpWaiting,
          McpInventoryNotFound() => loc.mcpNotFound,
          McpInventoryReadFailed() || McpInventoryFailed() => loc.mcpReadFailed,
        },
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      children: [
        Text(server.name, style: context.prego.textTheme.textLg.medium),
        if (server.description case final description?) Text(description),
        const SizedBox(height: PregoSpacing.md),
        PregoGroupedRows(
          color: context.prego.colors.bgSurface2,
          children: [
            PregoGroupedRow(
              title: Text(loc.mcpConnection),
              subtitle: Text(_connection(connection: server.connection, loc: loc)),
            ),
            PregoGroupedRow(
              title: Text(loc.mcpAuthorization),
              subtitle: Text(switch (server.authorization) {
                McpAuthorizationState.unknown => loc.mcpUnknown,
                McpAuthorizationState.notRequired => loc.mcpAuthNotRequired,
                McpAuthorizationState.required => loc.mcpAuthRequired,
                McpAuthorizationState.authenticated => loc.mcpAuthenticated,
              }),
            ),
            if (server.endpointOrigin case final origin?)
              PregoGroupedRow(title: Text(loc.mcpOrigin), subtitle: Text(origin)),
            PregoGroupedRow(
              title: Text(loc.mcpConfiguration),
              subtitle: Text(switch (server.configuration?.scope) {
                null || McpConfigurationScope.unknown => loc.mcpUnknown,
                McpConfigurationScope.harness => loc.mcpHarnessScope,
                McpConfigurationScope.project => loc.mcpProjectScope,
                McpConfigurationScope.session => loc.mcpSessionScope,
              }),
            ),
            PregoGroupedRow(
              title: Text(loc.mcpConfigurationAccess),
              subtitle: Text(switch (server.configuration?.mutability) {
                null || McpConfigurationMutability.unknown => loc.mcpUnknown,
                McpConfigurationMutability.userManaged => loc.mcpUserManaged,
                McpConfigurationMutability.readOnly => loc.mcpReadOnlyConfiguration,
              }),
            ),
          ],
        ),
        const SizedBox(height: PregoSpacing.xl),
        SettingsSection(
          title: loc.mcpTools,
          child: switch (server.tools) {
            McpToolsAvailable(:final tools) when tools.isNotEmpty => PregoGroupedRows(
              color: context.prego.colors.bgSurface2,
              children: [
                for (final tool in tools)
                  PregoGroupedRow(
                    title: Text(tool.name),
                    subtitle: switch (tool.description) {
                      final description? => Text(description),
                      null => null,
                    },
                  ),
              ],
            ),
            McpToolsAvailable() => Text(loc.mcpNoTools),
            McpToolsUnavailable() => Text(loc.mcpToolsUnavailable),
            McpToolsFailed() => Text(loc.mcpToolsFailed),
          },
        ),
      ],
    );
  }
}

String _connection({required McpConnectionState connection, required AppLocalizations loc}) => switch (connection) {
  McpConnectionUnknown() => loc.mcpUnknown,
  McpConnectionFailed() => loc.mcpConnectionFailed,
  McpConnectionStatus(:final phase) => switch (phase) {
    McpConnectionPhase.unknown => loc.mcpUnknown,
    McpConnectionPhase.pending => loc.mcpPending,
    McpConnectionPhase.connecting => loc.mcpConnecting,
    McpConnectionPhase.connected => loc.mcpConnected,
    McpConnectionPhase.authenticationRequired => loc.mcpAuthRequired,
    McpConnectionPhase.disabled => loc.mcpDisabled,
  },
};

class const _Message({required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(PregoSpacing.lg),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
