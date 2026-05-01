import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids usage of the `Object` or `dynamic` type.
///
/// Using `Object` or `dynamic` defeats the purpose of Dart's type system and can hide bugs.
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
/// - `Object foo;` - untyped Object usage
/// - `List<Object?> items;` - Object? in generic
///
/// Valid examples (exceptions):
/// - `factory Foo.fromJson(Map<String, dynamic> json)` - fromJson factory
/// - `static Foo fromJson(Map<String, dynamic> json)` - fromJson static method
/// - `Map<String, dynamic> toJson()` - toJson method return type
/// - `external dynamic foo();` - external declarations (JS interop)
/// - `@override void foo(dynamic x)` - parameters in overridden methods
class PreferSpecificTypeRule extends NoSlopRule {
  PreferSpecificTypeRule({required super.ignoreTestFiles})
    : super(
        name: code.lowerCaseName,
        description: 'Forbids usage of the Object or dynamic type.',
      );

  static const code = LintCode(
    'prefer_specific_type',
    "Avoid using 'Object' or 'dynamic' type. Use explicit types instead.",
    correctionMessage: 'Replace Object or dynamic with a specific type.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addNamedType(this, _Visitor(this));
  }

  /// Checks if this dynamic usage is allowed.
  bool _isAllowedDynamic(NamedType dynamicNode) {
    if (_isInExternalDeclaration(dynamicNode)) return true;
    if (_isInOverriddenMethod(dynamicNode)) return true;
    if (_isInFunctionArgument(dynamicNode)) return true;

    final typeArgumentList = dynamicNode.parent;
    if (typeArgumentList is! TypeArgumentList) return false;

    final typeArguments = typeArgumentList.arguments;
    if (typeArguments.length != 2) return false;
    if (typeArguments[1] != dynamicNode) return false;

    final firstArg = typeArguments[0];
    if (firstArg is! NamedType || firstArg.name.lexeme != 'String') {
      return false;
    }

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

  /// Any `Object` or `dynamic` inside a method that has `@override` is
  /// acceptable — the signature is dictated by the base class/interface.
  bool _isInOverriddenMethod(AstNode node) {
    final method = _findAncestorOfType<MethodDeclaration>(node);
    if (method != null) {
      return _hasOverrideAnnotation(method);
    }
    return false;
  }

  /// Catch-all catch clauses (`on Object catch (e)`) need `Object` to catch
  /// every possible thrown value. This is idiomatic and outside the developer's
  /// control.
  bool _isInCatchClause(NamedType node) {
    return _findAncestorOfType<CatchClause>(node) != null;
  }

  /// When a function expression is passed as an argument (callback / lambda)
  /// the developer does not control the expected signature, so `Object` or
  /// `dynamic` in the callback's parameters should not be flagged.
  bool _isInFunctionArgument(NamedType node) {
    final parameter = _findAncestorOfType<FormalParameter>(node);
    if (parameter == null) return false;

    final functionExpression = _findAncestorOfType<FunctionExpression>(node);
    if (functionExpression == null) return false;

    final parent = functionExpression.parent;
    return parent is ArgumentList || parent is NamedExpression;
  }

  /// Generic bounds (`T extends Object?`) are outside the developer's control —
  /// they describe the constraint, not a concrete type choice.
  bool _isInGenericBound(NamedType node) {
    return _findAncestorOfType<TypeParameter>(node) != null;
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

  final PreferSpecificTypeRule rule;

  @override
  void visitNamedType(NamedType node) {
    if (rule.isCurrentFileExcluded) return;
    final name = node.name.lexeme;
    if (name == 'dynamic') {
      if (rule._isAllowedDynamic(node)) return;
      rule.reportAtNode(node);
    } else if (name == 'Object') {
      if (rule._isInExternalDeclaration(node)) return;
      if (rule._isInOverriddenMethod(node)) return;
      if (rule._isInCatchClause(node)) return;
      if (rule._isInFunctionArgument(node)) return;
      if (rule._isInGenericBound(node)) return;
      rule.reportAtNode(node);
    }
  }
}
