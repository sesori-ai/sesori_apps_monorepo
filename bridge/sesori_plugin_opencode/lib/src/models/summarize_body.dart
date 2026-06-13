/// Request body for OpenCode's `POST /session/:id/summarize` endpoint, which
/// triggers AI compaction of a session.
///
/// Unlike [SendCommandBody], which encodes the model as a single
/// `"providerID/modelID"` string, summarize requires the provider and model as
/// **separate** fields. `auto` distinguishes automatic (context-overflow)
/// compaction from a manual, user-initiated one; the bridge only ever triggers
/// the manual variant, so it defaults to `false`.
class SummarizeBody {
  final String providerID;
  final String modelID;
  final bool auto;

  const SummarizeBody({
    required this.providerID,
    required this.modelID,
    this.auto = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "providerID": providerID,
      "modelID": modelID,
      "auto": auto,
    };
  }
}
