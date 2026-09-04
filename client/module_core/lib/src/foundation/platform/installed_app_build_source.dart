abstract interface class InstalledAppBuildSource() {
  Future<String?> readBuildNumber();
}
