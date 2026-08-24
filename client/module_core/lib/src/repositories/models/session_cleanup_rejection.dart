import "package:sesori_shared/sesori_shared.dart" show CleanupIssue;

import "../../api/session_api.dart" show SessionCleanupApiRejectedException;

class const SessionCleanupRejection({required final List<CleanupIssue> issues});

class const SessionCleanupRejectedException({
  required final SessionCleanupRejection rejection,
  required final SessionCleanupApiRejectedException innerError,
}) implements Exception;
