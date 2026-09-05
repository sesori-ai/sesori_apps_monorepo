import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// A plugin event after the repository layer has translated its backend
/// session ids to bridge session ids and mapped its payload to shared values.
///
/// Consumers above the repository read these values directly instead of
/// re-parsing plugin payloads or calling repository mapping policy. Kinds not
/// yet given a typed payload travel as [NormalizedOtherEvent]; that wrapper is
/// produced only by the exhaustive normalizer and is not a fallback path.
sealed class const NormalizedBridgeEvent();

/// The payload variants a normalized event can carry.
sealed class const NormalizedBridgePayload() extends NormalizedBridgeEvent;

/// A session's status, for the bridge session [sessionId].
final class const NormalizedStatusEvent({
  required final String sessionId,
  required final SessionStatus status,
}) extends NormalizedBridgePayload;

/// An already id-normalized plugin event whose payload keeps its plugin shape.
final class const NormalizedOtherEvent({required final BridgeSseEvent event}) extends NormalizedBridgePayload;

/// The normalized form of [BridgeSseTerminalHandoff]: reconciliation
/// synthesized during a forced stop, carrying no stop-fence authority of its
/// own. A handoff never wraps another handoff.
final class const NormalizedTerminalHandoff({required final NormalizedBridgePayload payload})
    extends NormalizedBridgeEvent;
