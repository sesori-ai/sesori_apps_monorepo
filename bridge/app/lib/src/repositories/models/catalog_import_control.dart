class CatalogImportControl({
    required this.explicitImportRequested,
    required this.hydrationMarkerRequested,
  }) {
  bool cancellationRequested = false;
  bool explicitImportRequested;
  bool hydrationMarkerRequested;
}
