import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';

/// Shared helper mixin for exhaustive switch fixes.
///
/// Provides common logic for finding missing enum/sealed class values
/// and extracting handled patterns from switch nodes.
mixin _ExhaustiveSwitchFixHelpers {
  /// Extracts the missing values and default body from a switch expression case.
  ({List<String> missingValues, String defaultBody})? _analyzeExpressionCase(
    SwitchExpressionCase wildcardCase,
    SwitchExpression switchExpr,
  ) {
    final expressionType = switchExpr.expression.staticType;
    if (expressionType == null) return null;

    final element = expressionType.element;
    if (element == null) return null;

    final defaultBody = wildcardCase.expression.toSource();

    final handledCases = <String>{};
    var nullHandled = false;
    for (final member in switchExpr.cases) {
      final pattern = member.guardedPattern.pattern;
      if (pattern is! WildcardPattern) {
        _extractHandledPatterns(pattern, handledCases, expressionType);
        if (_isNullPattern(pattern)) {
          nullHandled = true;
        }
      }
    }

    final allValuesFullForm = _getAllValuesFullForm(element, expressionType);
    final allValuesShorthand = _getAllValues(element, expressionType);
    if (allValuesFullForm.isEmpty) return null;

    final missingIndices = <int>[];
    for (var i = 0; i < allValuesFullForm.length; i++) {
      if (!handledCases.contains(allValuesFullForm[i])) {
        missingIndices.add(i);
      }
    }

    final missingValues = missingIndices.map((i) => allValuesShorthand[i]).toList();

    final isNullable = expressionType.nullabilitySuffix == NullabilitySuffix.question;
    if (isNullable && !nullHandled) {
      missingValues.add('null');
    }

    if (missingValues.isEmpty) return null;

    return (missingValues: missingValues, defaultBody: defaultBody);
  }

  /// Extracts the missing values and default body from a switch statement default case.
  ({List<String> missingValues, String defaultStatements})? _analyzeStatementCase(
    SwitchDefault defaultCase,
    SwitchStatement switchStmt,
  ) {
    final expressionType = switchStmt.expression.staticType;
    if (expressionType == null) return null;

    final element = expressionType.element;
    if (element == null) return null;

    final defaultStatements = defaultCase.statements.map((s) => s.toSource()).join('\n');

    final handledCases = <String>{};
    var nullHandled = false;
    for (final member in switchStmt.members) {
      if (member is SwitchCase) {
        final expr = member.expression;
        if (expr is NullLiteral) {
          nullHandled = true;
        } else if (expr is PrefixedIdentifier) {
          handledCases.add(expr.toSource());
        } else if (expr is SimpleIdentifier) {
          handledCases.add(expr.toSource());
        }
      } else if (member is SwitchPatternCase) {
        final pattern = member.guardedPattern.pattern;
        _extractHandledPatterns(pattern, handledCases, expressionType);
        if (_isNullPattern(pattern)) {
          nullHandled = true;
        }
      }
    }

    final allValuesFullForm = _getAllValuesFullForm(element, expressionType);
    final allValuesShorthand = _getAllValues(element, expressionType);
    if (allValuesFullForm.isEmpty) return null;

    final missingIndices = <int>[];
    for (var i = 0; i < allValuesFullForm.length; i++) {
      if (!handledCases.contains(allValuesFullForm[i])) {
        missingIndices.add(i);
      }
    }

    final missingValues = missingIndices.map((i) => allValuesShorthand[i]).toList();

    final isNullable = expressionType.nullabilitySuffix == NullabilitySuffix.question;
    if (isNullable && !nullHandled) {
      missingValues.add('null');
    }

    if (missingValues.isEmpty) return null;

    return (missingValues: missingValues, defaultStatements: defaultStatements);
  }

  void _extractHandledPatterns(DartPattern pattern, Set<String> handledCases, DartType? switchType) {
    if (pattern is ConstantPattern) {
      final expr = pattern.expression;
      final source = expr.toSource();

      if (source.startsWith('.')) {
        final valueName = source.substring(1);
        final typeName = _getTypeName(switchType);
        if (typeName != null) {
          handledCases.add('$typeName.$valueName');
        } else {
          handledCases.add(source);
        }
      } else if (expr is PrefixedIdentifier) {
        handledCases.add(source);
      } else if (expr is SimpleIdentifier) {
        final valueName = expr.name;
        final typeName = _getTypeName(switchType);
        if (typeName != null) {
          handledCases.add('$typeName.$valueName');
        } else {
          handledCases.add(valueName);
        }
      } else {
        handledCases.add(source);
      }
    } else if (pattern is ObjectPattern) {
      if (!_hasConditionalFields(pattern)) {
        handledCases.add('${pattern.type.name.lexeme}()');
      }
    } else if (pattern is DeclaredVariablePattern) {
      final type = pattern.type;
      if (type is NamedType) {
        handledCases.add('${type.name.lexeme}()');
      }
    } else if (pattern is LogicalOrPattern) {
      _extractHandledPatterns(pattern.leftOperand, handledCases, switchType);
      _extractHandledPatterns(pattern.rightOperand, handledCases, switchType);
    }
  }

  String? _getTypeName(DartType? type) {
    if (type == null) return null;
    final element = type.element;
    if (element is EnumElement) {
      return element.name;
    }
    if (element is ClassElement) {
      return element.name;
    }
    return null;
  }

  bool _hasConditionalFields(ObjectPattern pattern) {
    for (final field in pattern.fields) {
      if (_isConditionalPattern(field.pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _isConditionalPattern(DartPattern pattern) {
    if (pattern is NullCheckPattern) return true;
    if (pattern is NullAssertPattern) return true;
    if (pattern is CastPattern) return true;
    return false;
  }

  bool _isNullPattern(DartPattern pattern) {
    if (pattern is ConstantPattern) {
      return pattern.expression is NullLiteral;
    }
    if (pattern is LogicalOrPattern) {
      return _isNullPattern(pattern.leftOperand) || _isNullPattern(pattern.rightOperand);
    }
    return false;
  }

  List<String> _getAllValues(Element element, DartType type, {bool useShorthand = true}) {
    if (element is EnumElement) {
      return element.fields
          .where((f) => f.isEnumConstant)
          .map((f) => useShorthand ? '.${f.name}' : '${element.name}.${f.name}')
          .toList();
    }

    if (element is ClassElement && element.isSealed) {
      return _getSealedClassSubtypes(element);
    }

    return [];
  }

  List<String> _getAllValuesFullForm(Element element, DartType type) {
    if (element is EnumElement) {
      final enumName = element.name;
      return element.fields.where((f) => f.isEnumConstant).map((f) => '$enumName.${f.name}').toList();
    }

    if (element is ClassElement && element.isSealed) {
      return _getSealedClassSubtypes(element);
    }

    return [];
  }

  List<String> _getSealedClassSubtypes(ClassElement sealedClass) {
    final subtypes = <String>[];
    final library = sealedClass.library;

    for (final element in library.children) {
      if (element is ClassElement) {
        if (element == sealedClass) continue;

        final supertype = element.supertype;
        if (supertype != null && supertype.element == sealedClass) {
          subtypes.add('${element.name}()');
          continue;
        }

        for (final interface in element.interfaces) {
          if (interface.element == sealedClass) {
            subtypes.add('${element.name}()');
            break;
          }
        }

        for (final mixin in element.mixins) {
          if (mixin.element == sealedClass) {
            subtypes.add('${element.name}()');
            break;
          }
        }
      } else if (element is EnumElement) {
        for (final interface in element.interfaces) {
          if (interface.element == sealedClass) {
            final enumName = element.name;
            for (final field in element.fields) {
              if (field.isEnumConstant) {
                subtypes.add('$enumName.${field.name}');
              }
            }
            break;
          }
        }
      }
    }

    return subtypes;
  }
}

/// A quick fix that replaces default/wildcard cases with a combined case pattern.
///
/// Example: `default:` -> `case EnumA.a || EnumA.b:`
class ExhaustiveSwitchCombinedFix extends ResolvedCorrectionProducer with _ExhaustiveSwitchFixHelpers {
  ExhaustiveSwitchCombinedFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.exhaustiveSwitchCombined',
    DartFixKindPriority.standard + 1,
    'Replace with combined case',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final targetNode = node;

    if (targetNode is SwitchExpressionCase && targetNode.guardedPattern.pattern is WildcardPattern) {
      final switchExpr = targetNode.parent;
      if (switchExpr is! SwitchExpression) return;

      final analysis = _analyzeExpressionCase(targetNode, switchExpr);
      if (analysis == null) return;

      final combinedPattern = analysis.missingValues.join(' || ');
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          '$combinedPattern => ${analysis.defaultBody}',
        );
      });
    } else if (targetNode is SwitchDefault) {
      final switchStmt = targetNode.parent;
      if (switchStmt is! SwitchStatement) return;

      final analysis = _analyzeStatementCase(targetNode, switchStmt);
      if (analysis == null) return;

      final combinedPattern = analysis.missingValues.join(' || ');
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          'case $combinedPattern:\n${analysis.defaultStatements}',
        );
      });
    }
  }
}

/// A quick fix that replaces default/wildcard cases with individual cases.
///
/// Example: `default:` -> `case EnumA.a:` + `case EnumA.b:`
class ExhaustiveSwitchIndividualFix extends ResolvedCorrectionProducer with _ExhaustiveSwitchFixHelpers {
  ExhaustiveSwitchIndividualFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.exhaustiveSwitchIndividual',
    DartFixKindPriority.standard,
    'Replace with individual cases',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final targetNode = node;

    if (targetNode is SwitchExpressionCase && targetNode.guardedPattern.pattern is WildcardPattern) {
      final switchExpr = targetNode.parent;
      if (switchExpr is! SwitchExpression) return;

      final analysis = _analyzeExpressionCase(targetNode, switchExpr);
      if (analysis == null || analysis.missingValues.length <= 1) return;

      final cases = analysis.missingValues.map((v) => '$v => ${analysis.defaultBody}').join(',\n');
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          cases,
        );
      });
    } else if (targetNode is SwitchDefault) {
      final switchStmt = targetNode.parent;
      if (switchStmt is! SwitchStatement) return;

      final analysis = _analyzeStatementCase(targetNode, switchStmt);
      if (analysis == null || analysis.missingValues.length <= 1) return;

      final cases = analysis.missingValues.map((v) => 'case $v:\n${analysis.defaultStatements}').join('\n');
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          cases,
        );
      });
    }
  }
}
