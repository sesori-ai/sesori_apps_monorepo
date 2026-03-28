/// The duration for which the bridge SSE manager buffers events for
/// disconnected subscribers. After this window, events are silently dropped.
///
/// Used by:
/// - Bridge `SSEManager` as the replay window duration
/// - Mobile `ConnectionService` (with safety margin) as the stale detection threshold
const Duration sseReplayWindow = Duration(minutes: 5);
