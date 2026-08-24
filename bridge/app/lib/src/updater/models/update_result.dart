enum UpdateResult(final String userFacingReason) {
  checksumFailed('the downloaded archive failed checksum verification'),
  downloadFailed('the release archive could not be downloaded or extracted'),
  alreadyLocked('another update is already in progress'),
  permissionDenied('permission denied writing to the install directory'),
  networkError('a network error occurred'),
}
