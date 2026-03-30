import "dart:async";

import "package:test/test.dart";

class _SocketMessageHarness {
  _SocketMessageHarness({required Object encryptor}) : _sessionEncryptor = encryptor;

  Object? _sessionEncryptor;
  bool _disposed = false;
  bool routedMessage = false;
  Object? decryptEncryptor;
  final Completer<void> decryptGate = Completer<void>();

  Future<void> onSocketMessage() async {
    final encryptor = _sessionEncryptor;
    if (encryptor == null) {
      return;
    }

    await _decryptRelayMessage(encryptor: encryptor);
    if (_disposed) return;

    routedMessage = true;
  }

  Future<void> _decryptRelayMessage({required Object encryptor}) async {
    decryptEncryptor = encryptor;
    await decryptGate.future;
  }

  void clearSessionEncryptor() {
    _sessionEncryptor = null;
  }

  void dispose() {
    _disposed = true;
  }
}

void main() {
  test("uses encryptor snapshot and exits when disposed after async gap", () async {
    final initialEncryptor = Object();
    final harness = _SocketMessageHarness(encryptor: initialEncryptor);

    final onMessageFuture = harness.onSocketMessage();
    await Future<void>.delayed(Duration.zero);

    harness.clearSessionEncryptor();
    harness.dispose();
    harness.decryptGate.complete();

    await onMessageFuture;

    expect(harness.decryptEncryptor, same(initialEncryptor));
    expect(harness.routedMessage, isFalse);
  });
}
