import "../../codex_app_server_client.dart";

/// The two app-server sources of pending user input.
sealed class const CodexPendingInput();

final class const CodexPendingRequest({required final CodexServerRequest request}) extends CodexPendingInput;

final class const CodexPendingNotification({required final CodexServerNotification notification})
    extends CodexPendingInput;
