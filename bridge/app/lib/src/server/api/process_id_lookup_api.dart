abstract class ProcessIdLookupApi {
  /// Finds processes whose platform executable name exactly matches
  /// [executableName]. The name excludes platform-specific extensions.
  Future<List<int>> listProcessIdsByExecutableName({required String executableName});
}
