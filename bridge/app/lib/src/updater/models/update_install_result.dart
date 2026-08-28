import 'package:meta/meta.dart';

import 'update_result.dart';

@immutable
sealed class const UpdateInstallResult();

final class const UpdateInstallStaged({required final String stagingPath}) extends UpdateInstallResult;

final class const UpdateInstallStageFailed({required final UpdateResult result}) extends UpdateInstallResult;
