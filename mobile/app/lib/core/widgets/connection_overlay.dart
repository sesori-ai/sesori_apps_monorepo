import "dart:ui";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_zyra/module_zyra.dart";

import "../di/injection.dart";
import "../extensions/build_context_x.dart";
import "../routing/app_router.dart";

/// App-wide overlay that reacts to [ConnectionService] status changes.
///
/// When [ConnectionLost]: blurs the screen and shows a card with
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
    final zyra = context.zyra;
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
              child: Material(
                elevation: 2,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      color: zyra.colors.bgBrandSolid,
                      backgroundColor: zyra.colors.bgTertiary,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.loc.relayReconnecting,
                        style: zyra.textTheme.textXs.medium.copyWith(
                          color: zyra.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Full overlay when connection is lost.
        if (showOverlay) ...[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: ColoredBox(color: Colors.black.withAlpha(100)),
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
    final zyra = context.zyra;
    final loc = context.loc;

    return Material(
      elevation: 2,
      color: Colors.orange.shade800,
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
                    style: zyra.textTheme.textXs.medium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    loc.bridgeOfflineMessage,
                    style: zyra.textTheme.textXs.regular.copyWith(
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
    final zyra = context.zyra;
    final loc = context.loc;

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: zyra.colors.fgErrorPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              loc.connectionLostTitle,
              style: zyra.textTheme.textMd.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              loc.relayConnectionLost,
              style: zyra.textTheme.textSm.regular,
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
