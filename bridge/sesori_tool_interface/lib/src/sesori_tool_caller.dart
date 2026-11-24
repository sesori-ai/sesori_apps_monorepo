/// The Sesori session behind one tool call.
///
/// Only the id: a group reads anything else about the session when it needs
/// it, so nothing about it goes stale.
final class const SesoriToolCaller({required final String sessionId});
