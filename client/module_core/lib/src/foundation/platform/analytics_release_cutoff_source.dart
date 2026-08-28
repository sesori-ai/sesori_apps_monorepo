abstract interface class AnalyticsReleaseCutoffSource() {
  Future<int?> fetchLatestSubmittedProductionBuild();
}
