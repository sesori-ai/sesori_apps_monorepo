import "dart:async";
import "dart:io" show WebSocket;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/v2_client_mcp_frame.dart";
import "../repositories/v2_sesori_tools_repository.dart";

/// Gives every OpenCode session Sesori's MCP tools, through OpenCode's
/// client-MCP WebSocket rather than any launch-time config: OpenCode's server
/// is shared with the user's own OpenCode apps, so nothing reaches the agent's
/// environment and the bridge's tokens never leave this process.
///
/// OpenCode scopes MCP servers per folder, so each folder in use gets one
/// socket, and this relays its JSON-RPC to the bridge's loopback server.
/// `initialize` and `tools/list` carry no session, so they use one grant
/// minted per socket. `tools/call` carries OpenCode's session id in `_meta`,
/// and each session gets its own grant, minted and bound on its first call.
/// The tools vanish when the socket closes.
///
/// A socket keeps its folder loaded in OpenCode, so a folder with no session
/// activity for [_idleRelease] lets its socket go, as OpenCode would unload it.
class V2SesoriToolsService({
  required final V2SesoriToolsRepository _repository,
  required final SesoriMcpAccess _access,

  /// How long a folder keeps its socket after its last session activity.
  required final Duration _idleRelease,

  /// How long a folder whose socket failed or closed waits before activity
  /// connects it again.
  required final Duration _retryDelay,

  /// How long a prompt waits for a connecting folder's tools.
  required final Duration _attachWait,
}) {
  final Map<String, _Folder> _folders = {};
  final Map<String, SesoriMcpLaunch> _sessionLaunches = {};
  Timer? _sweep;
  bool _disposed = false;

  /// Notes session activity in [directory] and connects its socket in the
  /// background when it has none.
  void touch({required String directory}) => unawaited(_link(directory: directory, retryNow: false));

  /// Like [touch], but waits until OpenCode has listed the folder's tools, or
  /// [_attachWait] passes, so that a prompt sent next can use them.
  Future<void> attach({required String directory}) =>
      _link(directory: directory, retryNow: false).timeout(_attachWait, onTimeout: () {});

  /// After OpenCode's event stream (re)connects, as after an OpenCode
  /// restart: links the folders still in use and the [loaded] ones now.
  void reconnect({required Set<String> loaded}) {
    for (final directory in {..._folders.keys, ...loaded}) {
      unawaited(_link(directory: directory, retryNow: true));
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sweep?.cancel();
    final sockets = [
      for (final folder in _folders.values)
        if (folder.link case _Open(:final socket)) socket,
    ];
    _folders.clear();
    await Future.wait([for (final socket in sockets) socket.close()]);
  }

  Future<void> _link({required String directory, required bool retryNow}) {
    if (_disposed) return Future.value();
    final folder = _folders.putIfAbsent(directory, _Folder.new)..lastActive = DateTime.now();
    _sweep ??= Timer.periodic(_idleRelease ~/ 6, (_) => _releaseIdle());
    switch (folder.link) {
      case _Connecting(:final listed) || _Open(:final listed):
        return listed.future;
      case _Closed(:final retryAt) when !retryNow && retryAt.isAfter(DateTime.now()):
        return Future.value();
      case _Closed():
    }

    final launch = _access.mint();
    if (launch == null) {
      // Agent tools are off; activity checks again after the delay.
      folder.link = _Closed(retryAt: DateTime.now().add(_retryDelay));
      return Future.value();
    }
    final connecting = _Connecting(listed: Completer<void>());
    folder.link = connecting;
    unawaited(_connect(directory: directory, folder: folder, connecting: connecting, launch: launch));
    return connecting.listed.future;
  }

  Future<void> _connect({
    required String directory,
    required _Folder folder,
    required _Connecting connecting,
    required SesoriMcpLaunch launch,
  }) async {
    final listed = connecting.listed;
    final WebSocket socket;
    try {
      socket = await _repository.connect(directory: directory);
    } on Object catch (error, stackTrace) {
      Log.w("[opencode-v2] could not attach Sesori tools to $directory", error, stackTrace);
      _close(folder: folder, link: connecting);
      return;
    }
    if (!identical(folder.link, connecting) || !identical(_folders[directory], folder)) {
      // Released or disposed while connecting.
      if (!listed.isCompleted) listed.complete();
      await socket.close();
      return;
    }
    final open = folder.link = _Open(listed: listed, socket: socket);
    Log.d("[opencode-v2] Sesori tools attaching to $directory");
    socket.listen(
      (frame) => unawaited(
        _answer(directory: directory, socket: socket, folderLaunch: launch, frame: frame, listed: listed),
      ),
      onError: (Object error, StackTrace stackTrace) {
        Log.w("[opencode-v2] Sesori tools socket for $directory failed", error, stackTrace);
      },
      onDone: () {
        Log.d("[opencode-v2] Sesori tools detached from $directory (${socket.closeCode} ${socket.closeReason})");
        _close(folder: folder, link: open);
      },
    );
  }

  /// Forgets a socket that failed or closed; activity links the folder again
  /// once [_retryDelay] passes.
  void _close({required _Folder folder, required _Link link}) {
    if (link case _Connecting(:final listed) || _Open(:final listed) when !listed.isCompleted) listed.complete();
    if (identical(folder.link, link)) folder.link = _Closed(retryAt: DateTime.now().add(_retryDelay));
  }

  Future<void> _answer({
    required String directory,
    required WebSocket socket,
    required SesoriMcpLaunch folderLaunch,
    required Object? frame,
    required Completer<void> listed,
  }) async {
    // Notifications and replies to nothing this side asked need no answer.
    final request = _repository.parse(frame: frame);
    if (request == null) return;
    final String reply;
    switch (request) {
      case V2ClientMcpSessionCall(:final sessionId):
        _folders[directory]?.lastActive = DateTime.now();
        final launch = _sessionLaunch(sessionId: sessionId);
        reply = launch == null
            ? _repository.toolError(request: request, text: "Sesori's agent tools are turned off on this computer.")
            : await _forward(request: request, launch: launch);
      case V2ClientMcpUnattributedCall():
        reply = _repository.toolError(request: request, text: "Sesori's tools work only inside an OpenCode session.");
      case V2ClientMcpListing() || V2ClientMcpOtherRequest():
        reply = await _forward(request: request, launch: folderLaunch);
    }
    try {
      socket.add(reply);
      // A socket OpenCode closed meanwhile refuses writes; it dropped the
      // request with the socket, so the reply has nowhere to go.
      // ignore: avoid_catching_errors
    } on StateError {
      return;
    }
    // OpenCode registers the tools once it has listed them.
    if (request is V2ClientMcpListing && !listed.isCompleted) listed.complete();
  }

  /// The grant that attributes calls to [sessionId], minted and bound once.
  SesoriMcpLaunch? _sessionLaunch({required String sessionId}) {
    final cached = _sessionLaunches[sessionId];
    if (cached != null) return cached;
    final launch = _access.mint();
    if (launch == null) return null;
    _access.bind(launch: launch, backendSessionId: sessionId);
    return _sessionLaunches[sessionId] = launch;
  }

  Future<String> _forward({required V2ClientMcpRequest request, required SesoriMcpLaunch launch}) async {
    try {
      return await _repository.forward(request: request, launch: launch);
    } on Object catch (error, stackTrace) {
      Log.w("[opencode-v2] the Sesori bridge did not answer", error, stackTrace);
      return _repository.unanswered(request: request);
    }
  }

  void _releaseIdle() {
    final cutoff = DateTime.now().subtract(_idleRelease);
    _folders.removeWhere((directory, folder) {
      if (folder.lastActive.isAfter(cutoff)) return false;
      Log.d("[opencode-v2] releasing the Sesori tools socket of idle $directory");
      if (folder.link case _Open(:final socket)) unawaited(socket.close());
      return true;
    });
  }
}

final class _Folder() {
  DateTime lastActive = DateTime.now();
  _Link link = _Closed(retryAt: DateTime.now());
}

/// A folder's socket. [listed] completes once OpenCode has listed the tools,
/// or the attempt has ended.
sealed class _Link();

final class _Connecting({required final Completer<void> listed}) extends _Link;

final class _Open({required final Completer<void> listed, required final WebSocket socket}) extends _Link;

/// No socket; activity opens one from [retryAt].
final class _Closed({required final DateTime retryAt}) extends _Link;
