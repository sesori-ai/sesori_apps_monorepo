import "dart:async";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console;
import "package:sesori_shared/sesori_shared.dart";

import "login_oauth_api.dart";
import "token.dart";

const int _totalLoginTimeoutSeconds = 300; // 5 minutes, matching server session expiry
const int _perRequestTimeoutSeconds = 35; // Slightly longer than server's 30s long poll
const Duration _defaultPollInterval = Duration(milliseconds: 250);
const Duration _defaultPollTimeout = Duration(seconds: _totalLoginTimeoutSeconds);
const Duration _defaultPerRequestTimeout = Duration(seconds: _perRequestTimeoutSeconds);

/// Opens the default browser to [url].
///
/// Platform-specific:
/// - macOS: `open`
/// - Linux: `xdg-open`
/// - Windows: `rundll32 url.dll,FileProtocolHandler`
Future<void> openOAuthBrowser(String url) async {
  late final ProcessResult result;
  if (Platform.isMacOS) {
    result = await Process.run("open", [url]);
  } else if (Platform.isLinux) {
    result = await Process.run("xdg-open", [url]);
  } else if (Platform.isWindows) {
    // Hand the URL straight to the shell's protocol handler via rundll32
    // instead of `cmd /c start`. cmd.exe treats the `&` query-string
    // separators in an OAuth URL as command separators — it runs the first
    // segment and then tries to execute each remaining "name=value" fragment
    // as its own command — and `start` would additionally misread the URL as a
    // window title. rundll32 is launched without a shell, so the URL (every
    // `&` included) reaches the default browser verbatim.
    result = await Process.run("rundll32", ["url.dll,FileProtocolHandler", url]);
  } else {
    throw UnsupportedError("Unsupported platform: ${Platform.operatingSystem}");
  }

  if (result.exitCode != 0) {
    throw Exception("Browser launcher exited with code ${result.exitCode}: ${result.stderr}");
  }
}

/// Confidence that a URL can be opened in a graphical browser on this host.
enum BrowserOpenability {
  /// A graphical browser is almost certainly reachable — open it confidently.
  yes,

  /// No graphical browser is reachable (headless host, or an SSH session on a
  /// platform where SSH cannot reach the desktop). Don't attempt a launch.
  no,

  /// Cannot be decided from the environment alone — attempt a best-effort open
  /// and rely on the always-printed URL when it turns out to be a no-op.
  unknown,
}

/// Detects whether a graphical browser can be launched on this host from the
/// environment and platform. Injected into [LoginOAuthService] so tests can
/// force a specific outcome; the decision table itself lives in the pure
/// [resolveBrowserOpenability] for direct testing.
BrowserOpenability detectBrowserOpenability() {
  final env = Platform.environment;
  final isLinux = Platform.isLinux;
  return resolveBrowserOpenability(
    isLinux: isLinux,
    isMacOS: Platform.isMacOS,
    isWindows: Platform.isWindows,
    hasDisplay: (env["DISPLAY"] ?? "").isNotEmpty || (env["WAYLAND_DISPLAY"] ?? "").isNotEmpty,
    isWsl: isLinux && _isWindowsSubsystemForLinux(env),
    isSsh: _isSshSession(env),
  );
}

/// Pure decision table for [detectBrowserOpenability], split out so the
/// per-platform reasoning is unit-testable without touching the real host.
///
/// Mirrors CPython's `webbrowser` gating on Linux (a GUI browser is only
/// reachable when `DISPLAY`/`WAYLAND_DISPLAY` is set, which also covers SSH X11
/// forwarding and WSLg). WSL without a display may still reach the Windows
/// browser via `wslview`, so it is `unknown` rather than `no`. SSH into Windows
/// cannot reach the interactive desktop, so it is `no`; a local Windows or
/// SSH-on-macOS session can't be proven either way without platform APIs, so it
/// stays `unknown`.
@visibleForTesting
BrowserOpenability resolveBrowserOpenability({
  required bool isLinux,
  required bool isMacOS,
  required bool isWindows,
  required bool hasDisplay,
  required bool isWsl,
  required bool isSsh,
}) {
  if (isLinux) {
    if (hasDisplay) {
      return BrowserOpenability.yes;
    }
    if (isWsl) {
      return BrowserOpenability.unknown;
    }
    return BrowserOpenability.no;
  }
  if (isMacOS) {
    return isSsh ? BrowserOpenability.unknown : BrowserOpenability.yes;
  }
  if (isWindows) {
    return isSsh ? BrowserOpenability.no : BrowserOpenability.unknown;
  }
  return BrowserOpenability.no;
}

bool _isSshSession(Map<String, String> env) =>
    (env["SSH_CONNECTION"] ?? "").isNotEmpty ||
    (env["SSH_CLIENT"] ?? "").isNotEmpty ||
    (env["SSH_TTY"] ?? "").isNotEmpty;

bool _isWindowsSubsystemForLinux(Map<String, String> env) {
  if ((env["WSL_DISTRO_NAME"] ?? "").isNotEmpty || (env["WSL_INTEROP"] ?? "").isNotEmpty) {
    return true;
  }
  // Fallback for shells that drop the WSL_* vars (e.g. after sudo): the WSL
  // kernel advertises itself in /proc/version.
  try {
    return File("/proc/version").readAsStringSync().toLowerCase().contains("microsoft");
  } on IOException {
    return false;
  }
}

class LoginOAuthService {
  final LoginOAuthApi _api;
  final Future<void> Function(String url) _browserLauncher;
  final BrowserOpenability Function() _browserOpenability;
  final Duration _pollInterval;
  final Duration _pollTimeout;
  final Duration _perRequestTimeout;
  final Future<void> Function(Duration duration) _delay;

  LoginOAuthService({
    required LoginOAuthApi api,
    required Future<void> Function(String url) browserLauncher,
    required BrowserOpenability Function() browserOpenability,
    @visibleForTesting Duration pollInterval = _defaultPollInterval,
    @visibleForTesting Duration pollTimeout = _defaultPollTimeout,
    @visibleForTesting Duration perRequestTimeout = _defaultPerRequestTimeout,
    @visibleForTesting Future<void> Function(Duration duration)? delay,
  }) : _api = api,
       _browserLauncher = browserLauncher,
       _browserOpenability = browserOpenability,
       _pollInterval = pollInterval,
       _pollTimeout = pollTimeout,
       _perRequestTimeout = perRequestTimeout,
       _delay = delay ?? Future<void>.delayed;

  /// Starts the OAuth login flow through the auth backend's pending-session API.
  ///
  /// The temporary session token is generated in memory, sent only through the
  /// `X-Sesori-Session-Token` header, and never persisted or placed in URLs.
  Future<({TokenData tokens, String sessionToken})> performOAuthLogin(OAuthProvider provider) async {
    final sessionToken = _generateSessionToken();
    final initResp = await _api.initOAuthSession(
      provider: provider,
      sessionToken: sessionToken,
    );

    _printUserCode(initResp.userCode);

    // The URL is ALWAYS printed, on its own line, so login works even when no
    // browser can be opened: the bridge frequently runs headless (servers, SSH
    // sessions, containers), and a launcher exit code of 0 only means the OS
    // accepted the request, not that a browser actually appeared. We attempt an
    // automatic open unless we're confident none is reachable, and soften the
    // wording from "Opening" to "Attempting to open" when it's uncertain. The
    // messaging is identical across platforms — only the environment differs.
    final openability = _browserOpenability();
    switch (openability) {
      case BrowserOpenability.yes:
        Console.message("Opening your browser to complete ${provider.label} login...");
        Console.message("If it doesn't open automatically, open this URL manually to continue:");
      case BrowserOpenability.unknown:
        Console.message("Attempting to open your browser to complete ${provider.label} login...");
        Console.message("If it doesn't open, open this URL manually to continue:");
      case BrowserOpenability.no:
        Console.message("No graphical browser detected (e.g. a headless or SSH session).");
        Console.message("Open this URL to complete ${provider.label} login:");
    }
    Console.message(initResp.authUrl);
    if (openability != BrowserOpenability.no) {
      try {
        await _browserLauncher(initResp.authUrl);
      } catch (e) {
        Console.message("Could not open a browser automatically; open the URL above manually: $e");
      }
    }

    Console.message("Waiting for authorization...");
    final tokens = await _pollForCompletion(provider: provider, sessionToken: sessionToken);
    return (tokens: tokens, sessionToken: sessionToken);
  }

  Future<void> ackOAuthSessionCompletion({required String sessionToken}) {
    return _api.ackOAuthSessionCompletion(sessionToken: sessionToken);
  }

  Future<TokenData> _pollForCompletion({
    required OAuthProvider provider,
    required String sessionToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      while (stopwatch.elapsed < _pollTimeout) {
        final remaining = _pollTimeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) break;
        final requestTimeout = remaining < _perRequestTimeout ? remaining : _perRequestTimeout;
        final status = await _api.getOAuthSessionStatus(sessionToken: sessionToken).timeout(requestTimeout);

        switch (status) {
          case AuthSessionStatusResponsePending():
            final delay = _pollInterval < remaining ? _pollInterval : remaining;
            if (delay > Duration.zero) {
              await _delay(delay);
            }
          case AuthSessionStatusResponseComplete(:final accessToken, :final refreshToken, :final user):
            if (accessToken.isEmpty || refreshToken.isEmpty) {
              throw Exception("auth session response missing tokens");
            }
            final username = user.providerUsername ?? "";
            if (username.isNotEmpty) {
              Console.message("Login successful! Welcome, $username");
            } else {
              Console.message("Login successful!");
            }
            return TokenData(
              accessToken: accessToken,
              refreshToken: refreshToken,
              bridgeId: null,
              lastProvider: provider,
            );
          case AuthSessionStatusResponseDenied():
            throw Exception("authorization denied");
          case AuthSessionStatusResponseExpired():
            throw Exception("authorization expired");
          case AuthSessionStatusResponseError(:final message):
            throw Exception("authorization failed: $message");
        }
      }

      throw TimeoutException("timed out waiting for authorization", _pollTimeout);
    } finally {
      stopwatch.stop();
    }
  }

  void _printUserCode(String userCode) {
    const line = "┌──────────────────────────────────────────┐";
    const empty = "│                                          │";
    const contentWidth = 42; // width inside the box borders

    final codeText = "CODE:  $userCode";
    final codePadding = " " * ((contentWidth - codeText.length) ~/ 2);
    final codeLine = "│$codePadding$codeText${" " * (contentWidth - codePadding.length - codeText.length)}│";

    const confirmText = "Confirm this code on the web page";
    final confirmPadding = " " * ((contentWidth - confirmText.length) ~/ 2);
    final confirmLine =
        "│$confirmPadding$confirmText${" " * (contentWidth - confirmPadding.length - confirmText.length)}│";

    const beforeText = "before approving the login request.";
    final beforePadding = " " * ((contentWidth - beforeText.length) ~/ 2);
    final beforeLine = "│$beforePadding$beforeText${" " * (contentWidth - beforePadding.length - beforeText.length)}│";

    const bottomLine = "└──────────────────────────────────────────┘";

    // Printed as a single write so the box renders atomically as one block.
    Console.message(
      [
        "",
        line,
        empty,
        codeLine,
        empty,
        confirmLine,
        beforeLine,
        empty,
        bottomLine,
        "",
      ].join("\n"),
    );
  }

  String _generateSessionToken() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }

    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  }
}
