import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that enforces required named parameters for functions with
/// multiple arguments.
///
/// At most one positional parameter is allowed. Nullable named parameters must
/// be marked as `required` unless they have an explicit default value.
/// Non-nullable params don't need `required` since Dart enforces they must be
/// provided (or have a default).
///
/// Examples that trigger this rule:
/// - `void foo(String a, int b)` - multiple positional parameters
/// - `void foo(String a, {int? b})` - nullable named but not required
/// - `void foo({required int a, int? b})` - b is nullable without required
///
/// Valid examples:
/// - `void foo(String a)` - single positional (OK)
/// - `void foo(String a, {required int? b})` - nullable with required (OK)
/// - `void foo({required String a, int b})` - non-nullable doesn't need required (OK)
/// - `void foo({required String a, int b = 0})` - default value (OK)
/// - `void foo({String a, int b})` - non-nullable params are OK without required
/// - Callbacks like `void Function(String, int)` are allowed
/// - Overridden methods are allowed (must match parent signature)
/// - Super parameters (e.g., super.key) are skipped (delegated to parent)
/// - DI-annotated classes (@injectable, @singleton, @lazySingleton) are skipped
/// - Nullable function-type params (e.g., `{void Function()? onCancel}`) are OK
/// - Parameters with @QueryParam() annotation (route params) are OK
/// - Functions with @pragma annotations (compiler hints) are skipped
class PreferRequiredNamedParametersRule extends NoSlopMultiRule {
  PreferRequiredNamedParametersRule()
      : super(
          name: codePositionalParams.lowerCaseName,
          description: 'Enforces required named parameters for multi-argument functions.',
        );

  static const codePositionalParams = LintCode(
    'prefer_required_named_parameters',
    'Make named: {0} (only 1 positional allowed)',
    correctionMessage: 'Use named parameters: {required Type name} or {Type name = default}.',
    uniqueName: 'LintCode.prefer_required_named_parameters.positional',
  );

  static const codeMissingRequired = LintCode(
    'prefer_required_named_parameters',
    'Add required or default: {0}',
    correctionMessage: 'Use named parameters: {required Type name} or {Type name = default}.',
    uniqueName: 'LintCode.prefer_required_named_parameters.required',
  );

  @override
  List<DiagnosticCode> get diagnosticCodes => [codePositionalParams, codeMissingRequired];

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this);
    registry.addFunctionDeclaration(this, visitor);
    registry.addMethodDeclaration(this, visitor);
    registry.addConstructorDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final PreferRequiredNamedParametersRule rule;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.externalKeyword != null) return;
    if (_hasPragmaAnnotation(node.metadata)) return;

    _checkParameters(parameters: node.functionExpression.parameters);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (rule.isCurrentFileExcluded) return;
    if (_hasOverrideAnnotation(node)) return;
    if (node.externalKeyword != null) return;
    if (_hasPragmaAnnotation(node.metadata)) return;

    _checkParameters(parameters: node.parameters);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.externalKeyword != null) return;
    if (node.parent?.parent is EnumDeclaration) return;
    if (_isInDiAnnotatedClass(node)) return;

    _checkParameters(parameters: node.parameters);
  }

  void _checkParameters({required FormalParameterList? parameters}) {
    if (parameters == null) return;

    final params = parameters.parameters;
    if (params.length <= 1) return;

    final positionalParams = <String>[];
    final missingRequiredParams = <String>[];
    var positionalCount = 0;

    for (final param in params) {
      if (_isSuperParameter(param)) continue;

      final paramName = _getParameterName(param);

      if (!param.isNamed) {
        positionalCount++;
        if (positionalCount > 1) {
          positionalParams.add(paramName);
        }
        continue;
      }

      if (param is DefaultFormalParameter) {
        final isRequired = param.isRequired;
        final hasDefault = param.defaultValue != null;

        if (!isRequired && !hasDefault) {
          if (!_isNullableParameter(param) && !_isNullableFunctionParameter(param)) {
            continue;
          }
          if (_isNullableFunctionParameter(param)) {
            continue;
          }
          if (_hasQueryParamAnnotation(param)) {
            continue;
          }
          missingRequiredParams.add(paramName);
        }
      }
    }

    if (positionalParams.isNotEmpty) {
      rule.reportAtNode(
        parameters,
        diagnosticCode: PreferRequiredNamedParametersRule.codePositionalParams,
        arguments: [positionalParams.join(', ')],
      );
    }
    if (missingRequiredParams.isNotEmpty) {
      rule.reportAtNode(
        parameters,
        diagnosticCode: PreferRequiredNamedParametersRule.codeMissingRequired,
        arguments: [missingRequiredParams.join(', ')],
      );
    }
  }

  String _getParameterName(FormalParameter param) {
    if (param is DefaultFormalParameter) {
      return param.parameter.name?.lexeme ?? '?';
    }
    return param.name?.lexeme ?? '?';
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
    }
    return false;
  }

  bool _isNullableFunctionParameter(DefaultFormalParameter param) {
    final innerParam = param.parameter;
    if (innerParam is SimpleFormalParameter) {
      final type = innerParam.type;
      if (type is GenericFunctionType) {
        return type.question != null;
      }
    }
    return false;
  }

  bool _hasQueryParamAnnotation(FormalParameter param) {
    final metadata = param.metadata;
    for (final annotation in metadata) {
      if (annotation.name.name == 'QueryParam' || annotation.name.name == 'queryParam') {
        return true;
      }
    }
    return false;
  }

  bool _hasOverrideAnnotation(MethodDeclaration node) {
    for (final annotation in node.metadata) {
      if (annotation.name.name == 'override') {
        return true;
      }
    }
    return false;
  }

  bool _hasPragmaAnnotation(NodeList<Annotation> metadata) {
    for (final annotation in metadata) {
      if (annotation.name.name == 'pragma') {
        return true;
      }
    }
    return false;
  }

  static const _diAnnotations = {
    'injectable',
    'Injectable',
    'singleton',
    'Singleton',
    'lazySingleton',
    'LazySingleton',
  };

  bool _isInDiAnnotatedClass(ConstructorDeclaration node) {
    final classDecl = node.parent?.parent;
    if (classDecl is! ClassDeclaration) return false;

    for (final annotation in classDecl.metadata) {
      if (_diAnnotations.contains(annotation.name.name)) {
        return true;
      }
    }
    return false;
  }
}
