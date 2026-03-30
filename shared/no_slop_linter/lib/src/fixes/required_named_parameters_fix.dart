import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

/// Shared helper mixin for required named parameter fixes.
mixin _RequiredNamedParamsFixHelpers {
  /// Collects positional and named parameters, skipping super parameters.
  ({List<FormalParameter> positionalParams, List<FormalParameter> namedParams}) _collectParams(
    FormalParameterList paramList,
  ) {
    final positionalParams = <FormalParameter>[];
    final namedParams = <FormalParameter>[];

    for (final param in paramList.parameters) {
      if (_isSuperParameter(param)) {
        positionalParams.add(param);
        continue;
      }

      if (param.isNamed) {
        namedParams.add(param);
      } else {
        positionalParams.add(param);
      }
    }

    return (positionalParams: positionalParams, namedParams: namedParams);
  }

  /// Convert a positional parameter to a required named parameter.
  String _convertToRequiredNamed(FormalParameter param) {
    return _insertRequired(param);
  }

  /// Ensure a named param has 'required' if it's nullable without a default.
  String _ensureRequired(FormalParameter param) {
    if (param is DefaultFormalParameter) {
      final isRequired = param.isRequired;
      final hasDefault = param.defaultValue != null;

      if (!isRequired && !hasDefault && _isNullableParameter(param)) {
        return _insertRequired(param);
      }
    }
    return param.toSource();
  }

  /// Insert 'required' keyword in the correct position.
  String _insertRequired(FormalParameter param) {
    final source = param.toSource();
    final annotations = param.metadata;

    if (annotations.isEmpty) {
      return 'required $source';
    }

    final lastAnnotation = annotations.last;
    final annotationEnd = lastAnnotation.end - param.offset;

    final beforeRequired = source.substring(0, annotationEnd);
    var afterRequired = source.substring(annotationEnd);
    afterRequired = afterRequired.trimLeft();

    return '$beforeRequired required $afterRequired';
  }

  bool _isSuperParameter(FormalParameter param) {
    if (param is SuperFormalParameter) return true;
    if (param is DefaultFormalParameter) {
      return param.parameter is SuperFormalParameter;
    }
    return false;
  }

  bool _isNullableParameter(DefaultFormalParameter param) {
    final innerParam = param.parameter;
    if (innerParam is SimpleFormalParameter) {
      final type = innerParam.type;
      if (type is NamedType) {
        return type.question != null;
      }
      if (type is GenericFunctionType) {
        return type.question != null;
      }
    }
    return false;
  }

  /// Check if a named param needs 'required' added.
  bool _needsRequired(FormalParameter param) {
    if (param is DefaultFormalParameter) {
      final isRequired = param.isRequired;
      final hasDefault = param.defaultValue != null;
      return !isRequired && !hasDefault && _isNullableParameter(param);
    }
    return false;
  }
}

/// A quick fix that converts all positional params to required named params.
class RequiredNamedParamsAllNamedFix extends ResolvedCorrectionProducer with _RequiredNamedParamsFixHelpers {
  RequiredNamedParamsAllNamedFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.requiredNamedParamsAllNamed',
    DartFixKindPriority.standard + 1,
    'Convert all positional params to required named',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final paramList = node;
    if (paramList is! FormalParameterList) return;

    final (:positionalParams, :namedParams) = _collectParams(paramList);
    if (positionalParams.length <= 1) return;

    final newParams = <String>[];

    for (final param in positionalParams) {
      if (_isSuperParameter(param)) {
        newParams.add(param.toSource());
      } else {
        newParams.add(_convertToRequiredNamed(param));
      }
    }

    for (final param in namedParams) {
      newParams.add(_ensureRequired(param));
    }

    final newParamList = '({${newParams.join(', ')}})';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(paramList.offset, paramList.length),
        newParamList,
      );
    });
  }
}

/// A quick fix that keeps the first positional param and converts the rest to required named.
class RequiredNamedParamsKeepFirstFix extends ResolvedCorrectionProducer with _RequiredNamedParamsFixHelpers {
  RequiredNamedParamsKeepFirstFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.requiredNamedParamsKeepFirst',
    DartFixKindPriority.standard,
    'Keep first positional, convert rest to required named',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final paramList = node;
    if (paramList is! FormalParameterList) return;

    final (:positionalParams, :namedParams) = _collectParams(paramList);
    if (positionalParams.length <= 1) return;

    final positionalParts = <String>[];
    final namedParts = <String>[];

    for (var i = 0; i < positionalParams.length; i++) {
      final param = positionalParams[i];
      if (i == 0 || _isSuperParameter(param)) {
        positionalParts.add(param.toSource());
      } else {
        namedParts.add(_convertToRequiredNamed(param));
      }
    }

    for (final param in namedParams) {
      namedParts.add(_ensureRequired(param));
    }

    String newParamList;
    if (namedParts.isEmpty) {
      newParamList = '(${positionalParts.join(', ')})';
    } else {
      newParamList = '(${positionalParts.join(', ')}, {${namedParts.join(', ')}})';
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(paramList.offset, paramList.length),
        newParamList,
      );
    });
  }
}

/// A quick fix that adds 'required' to nullable named params that need it.
class RequiredNamedParamsAddRequiredFix extends ResolvedCorrectionProducer with _RequiredNamedParamsFixHelpers {
  RequiredNamedParamsAddRequiredFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.requiredNamedParamsAddRequired',
    DartFixKindPriority.standard,
    'Add required to nullable params',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final paramList = node;
    if (paramList is! FormalParameterList) return;

    final (:positionalParams, :namedParams) = _collectParams(paramList);

    // This fix only applies when there are no extra positional params
    if (positionalParams.length > 1) return;

    final paramsNeedingRequired = namedParams.where(_needsRequired).toList();
    if (paramsNeedingRequired.isEmpty) return;

    await builder.addDartFileEdit(file, (builder) {
      for (final param in paramsNeedingRequired) {
        final insertOffset = _getRequiredInsertOffset(param);
        builder.addSimpleInsertion(insertOffset, 'required ');
      }
    });
  }

  /// Gets the correct offset to insert 'required' keyword.
  int _getRequiredInsertOffset(FormalParameter param) {
    if (param is DefaultFormalParameter) {
      final innerParam = param.parameter;
      if (innerParam is SimpleFormalParameter) {
        final type = innerParam.type;
        if (type != null) {
          return type.offset;
        }
        final name = innerParam.name;
        if (name != null) {
          return name.offset;
        }
      }
      return innerParam.offset;
    }
    return param.offset;
  }
}
