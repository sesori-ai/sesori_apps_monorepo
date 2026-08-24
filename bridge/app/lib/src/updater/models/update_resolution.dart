import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';

import 'release_info.dart';

typedef EligibleUpdate = ({ReleaseInfo release, SemanticVersion version});

class const UpdateResolution({
  required final SemanticVersion currentVersion,
  required final bool currentEligible,
  required final EligibleUpdate? latest,
});
