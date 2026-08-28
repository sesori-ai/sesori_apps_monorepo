abstract interface class AndroidAnalyticsReleaseCutoffSource() {
  Future<int?> fetchLatestSubmittedProductionBuild();
}
