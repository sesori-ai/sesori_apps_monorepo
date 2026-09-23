/// Codex `model/list` and `turn/start`/`thread/start` service tier ids.
///
/// Codex's fast mode is exposed as a service tier: a model that offers it
/// lists a [fast] entry in its `serviceTiers`, and a turn opts into it by
/// setting `serviceTier: "priority"`. [standard] is the wire value that
/// explicitly returns a thread to standard speed (verified via
/// `codex app-server generate-json-schema`: `TurnStartParams.serviceTierForTurn`
/// documents 'Use "default" for standard speed'; `serviceTier` shares the
/// same tier vocabulary).
class CodexServiceTier._() {
  static const String fast = "priority";
  static const String standard = "default";
}
