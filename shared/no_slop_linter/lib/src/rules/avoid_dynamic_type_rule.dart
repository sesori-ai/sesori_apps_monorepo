import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids usage of the `dynamic` type.
///
/// Using `dynamic` defeats the purpose of Dart's type system and can hide bugs.
/// All variables, parameters, and return types should have explicit types.
///
/// Exceptions for JSON serialization patterns:
/// - `fromJson` methods/factories accepting `Map<String, dynamic>` parameter
/// - `toJson` methods returning `Map<String, dynamic>`
///
/// Examples that trigger this rule:
/// - `dynamic foo;` - dynamic variable
/// - `void bar(dynamic x) {}` - dynamic parameter
/// - `List<dynamic> items;` - dynamic in generic
/// - `Map<dynamic, String> map;` - dynamic as key type
///
/// Valid examples (exceptions):
/// - `factory Foo.fromJson(Map<String, dynamic> json)` - fromJson factory
/// - `static Foo fromJson(Map<String, dynamic> json)` - fromJson static method
/// - `Map<String, dynamic> toJson()` - toJson method return type
/// - `external dynamic foo();` - external declarations (JS interop)
/// - `@override void foo(dynamic x)` - parameters in overridden methods
class AvoidDynamicTypeRule extends NoSlopRule {
  AvoidDynamicTypeRule() : super(name: code.lowerCaseName, description: 'Forbids usage of the dynamic type.');

  static const code = LintCode(
    'avoid_dynamic_type',
    "Avoid using 'dynamic' type. Use explicit types instead.",
    correctionMessage: 'Replace dynamic with a specific type.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addNamedType(this, _Visitor(this));
  }

  /// Checks if this dynamic usage is allowed.
  bool _isAllowedDynamic(NamedType dynamicNode) {
    if (_isInExternalDeclaration(dynamicNode)) return true;
    if (_isInOverriddenMethodParameter(dynamicNode)) return true;

    final typeArgumentList = dynamicNode.parent;
    if (typeArgumentList is! TypeArgumentList) return false;

    final typeArguments = typeArgumentList.arguments;
    if (typeArguments.length != 2) return false;
    if (typeArguments[1] != dynamicNode) return false;

    final firstArg = typeArguments[0];
    if (firstArg is! NamedType || firstArg.name.lexeme != 'String') return false;

    final mapType = typeArgumentList.parent;
    if (mapType is! NamedType || mapType.name.lexeme != 'Map') return false;

    final parameter = _findAncestorOfType<FormalParameter>(mapType);
    if (parameter != null && _isInFromJsonMethod(parameter)) {
      return true;
    }

    if (_isToJsonReturnType(mapType)) {
      return true;
    }

    return false;
  }

  bool _isToJsonReturnType(NamedType mapType) {
    final method = _findAncestorOfType<MethodDeclaration>(mapType);
    if (method != null && method.returnType == mapType && method.name.lexeme == 'toJson') {
      return true;
    }

    final function = _findAncestorOfType<FunctionDeclaration>(mapType);
    if (function != null && function.returnType == mapType && function.name.lexeme == 'toJson') {
      return true;
    }

    return false;
  }

  bool _isInFromJsonMethod(FormalParameter parameter) {
    final constructor = _findAncestorOfType<ConstructorDeclaration>(parameter);
    if (constructor != null) {
      if (constructor.factoryKeyword != null && constructor.name?.lexeme == 'fromJson') {
        return true;
      }
    }

    final method = _findAncestorOfType<MethodDeclaration>(parameter);
    if (method != null) {
      if (method.name.lexeme == 'fromJson') {
        return true;
      }
    }

    final function = _findAncestorOfType<FunctionDeclaration>(parameter);
    if (function != null) {
      if (function.name.lexeme == 'fromJson') {
        return true;
      }
    }

    return false;
  }

  bool _isInExternalDeclaration(AstNode node) {
    final function = _findAncestorOfType<FunctionDeclaration>(node);
    if (function?.externalKeyword != null) return true;

    final method = _findAncestorOfType<MethodDeclaration>(node);
    if (method?.externalKeyword != null) return true;

    final constructor = _findAncestorOfType<ConstructorDeclaration>(node);
    if (constructor?.externalKeyword != null) return true;

    final field = _findAncestorOfType<FieldDeclaration>(node);
    if (field?.externalKeyword != null) return true;

    return false;
  }

  bool _isInOverriddenMethodParameter(AstNode node) {
    final parameter = _findAncestorOfType<FormalParameter>(node);
    if (parameter == null) return false;

    final method = _findAncestorOfType<MethodDeclaration>(node);
    if (method == null) return false;

    return _hasOverrideAnnotation(method);
  }

  bool _hasOverrideAnnotation(MethodDeclaration method) {
    for (final annotation in method.metadata) {
      if (annotation.name.name == 'override') {
        return true;
      }
    }
    return false;
  }

  T? _findAncestorOfType<T extends AstNode>(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is T) return current;
      current = current.parent;
    }
    return null;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidDynamicTypeRule rule;

  @override
  void visitNamedType(NamedType node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.name.lexeme != 'dynamic') return;
    if (rule._isAllowedDynamic(node)) return;
    rule.reportAtNode(node);
  }
}
