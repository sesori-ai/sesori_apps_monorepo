/// Links hand-written transcript records the way the CLI writes them: each
/// record with a `uuid` names the previous one as its `parentUuid`, unless it
/// sets its own. Records without a `uuid` and sub-agent records stay unlinked.
List<Map<String, Object?>> chainTranscriptRecords(List<Map<String, Object?>> records) {
  final chained = <Map<String, Object?>>[];
  String? previous;
  for (final record in records) {
    final uuid = record["uuid"];
    if (uuid is! String || record["isSidechain"] == true) {
      chained.add(record);
      continue;
    }
    chained.add({"parentUuid": previous, ...record});
    previous = uuid;
  }
  return chained;
}
