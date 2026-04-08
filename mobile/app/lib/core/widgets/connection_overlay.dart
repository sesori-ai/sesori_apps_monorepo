import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/injection.dart";
import "../extensions/build_context_x.dart";
import "../routing/app_router.dart";
import "../theme/sesori_theme_tokens.dart";

/// App-wide overlay that reacts to [ConnectionService] status changes.
///
/// When [ConnectionLost]: dims the screen and shows a card with
/// Reconnect / Disconnect actions.
/// When [ConnectionReconnecting]: shows a subtle progress bar at the top.
class ConnectionOverlay extends StatelessWidget {
  final Widget child;
  final GoRouter router;

  const ConnectionOverlay({super.key, required this.child, required this.router});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectionOverlayCubit(getIt<ConnectionService>(), getIt<AuthSession>()),
      child: _ConnectionOverlayBody(router: router, child: child),
    );
  }
}

class _ConnectionOverlayBody extends StatelessWidget {
  final Widget child;
  final GoRouter router;

  const _ConnectionOverlayBody({required this.child, required this.router});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ConnectionOverlayCubit>().state;
    final showOverlay = status is ConnectionLost;
    final isReconnecting = status is ConnectionReconnecting;
    final isBridgeOffline = status is ConnectionBridgeOffline;

    return Stack(
      children: [
        child,

        // Non-blocking bridge offline banner — user can still view the app.
        if (isBridgeOffline)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _BridgeOfflineBanner(),
            ),
          ),

        // Subtle reconnecting indicator — no blur, no blocking.
        if (isReconnecting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      context.loc.relayReconnecting,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Full overlay when connection is lost.
        if (showOverlay) ...[
          Positioned.fill(
            child: ColoredBox(
              color: themeOverlayScrim(context),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: _ConnectionLostCard(
                onReconnect: () => context.read<ConnectionOverlayCubit>().reconnect(),
                onDisconnect: () async {
                  await context.read<ConnectionOverlayCubit>().disconnect();
                  router.goRoute(const AppRoute.login());
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BridgeOfflineBanner extends StatelessWidget {
  const _BridgeOfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Material(
      elevation: 2,
      color: SesoriThemeTokens.offlineBanner,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.bridgeOfflineTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    loc.bridgeOfflineMessage,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionLostCard extends StatelessWidget {
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;

  const _ConnectionLostCard({
    required this.onReconnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              loc.connectionLostTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              loc.relayConnectionLost,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: OutlinedButton(
                    onPressed: onDisconnect,
                    child: Text(loc.connectionLostDisconnect),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: FilledButton.icon(
                    onPressed: onReconnect,
                    icon: const Icon(Icons.refresh),
                    label: Text(loc.connectionLostReconnect),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color themeOverlayScrim(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.light ? const Color(0xCCEEF2F8) : const Color(0xCC04070D);
}
