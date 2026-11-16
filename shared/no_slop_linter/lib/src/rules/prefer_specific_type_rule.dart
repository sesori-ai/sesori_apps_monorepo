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
/// Examples that trigger this rule:
/// - `dynamic foo;` - dynamic variable
/// - `void bar(dynamic x) {}` - dynamic parameter
/// - `List<dynamic> items;` - dynamic in generic
/// - `Map<dynamic, String> map;` - dynamic as key type
/// - `Object foo;` - untyped Object usage
/// - `List<Object?> items;` - Object? in generic
/// - `Map<String, Object> values;` - non-nullable Object map value
///
/// Valid examples (exceptions):
/// - `Map<String, dynamic>` and `Map<String, Object?>` - JSON maps, anywhere
/// - `T Function(dynamic json)`, `Foo parse(Object? json)` - JSON decode
///   callback parameters, recognised by the parameter name `json`
/// - `Object error`, `Object? cause`, `final Object innerError` - error values
///   whose name contains `error` or `cause` (not `dynamic`)
/// - `on Object catch (e)` - catch-all clauses
/// - `external dynamic foo();` - external declarations (JS interop)
/// - `@override void foo(dynamic x)` - parameters in overridden methods
/// - `(dynamic arg) => ...` passed as an argument - callback signatures
/// - `T extends Object?` - generic bounds
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

  bool _isAllowedDynamic(NamedType node) {
    if (_isInExternalDeclaration(node)) return true;
    if (_isInOverriddenMethod(node)) return true;
    if (_isInFunctionArgument(node)) return true;
    if (_isJsonMapValueType(node)) return true;
    if (_isJsonDecodeCallbackParameter(node)) return true;
    return false;
  }

  bool _isAllowedObject(NamedType node) {
    if (_isInExternalDeclaration(node)) return true;
    if (_isInOverriddenMethod(node)) return true;
    if (_isInCatchClause(node)) return true;
    if (_isInFunctionArgument(node)) return true;
    if (_isInGenericBound(node)) return true;
    if (_isErrorValue(node)) return true;
    final isNullable = node.question != null;
    if (isNullable && _isJsonMapValueType(node)) return true;
    if (isNullable && _isJsonDecodeCallbackParameter(node)) return true;
    return false;
  }

  /// The value type of a `Map<String, ...>` type or map literal: decoded JSON
  /// objects have heterogeneous values, so `Map<String, dynamic>` and
  /// `Map<String, Object?>` are the honest types for them.
  bool _isJsonMapValueType(NamedType node) {
    final typeArgumentList = node.parent;
    if (typeArgumentList is! TypeArgumentList) return false;

    final typeArguments = typeArgumentList.arguments;
    if (typeArguments.length != 2) return false;
    if (typeArguments[1] != node) return false;

    final keyType = typeArguments[0];
    if (keyType is! NamedType || keyType.name.lexeme != 'String') return false;

    final owner = typeArgumentList.parent;
    if (owner is SetOrMapLiteral) return true;
    return owner is NamedType && owner.name.lexeme == 'Map';
  }

  /// A parameter named `json` takes decoded JSON whose shape the callback
  /// checks itself, as in `T Function(dynamic json) fromJson`.
  bool _isJsonDecodeCallbackParameter(NamedType node) {
    final parameter = node.parent;
    return parameter is RegularFormalParameter && parameter.name?.lexeme == 'json';
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
    return parent is ArgumentList || parent is NamedArgument;
  }

  /// Generic bounds (`T extends Object?`) are outside the developer's control —
  /// they describe the constraint, not a concrete type choice.
  bool _isInGenericBound(NamedType node) {
    return _findAncestorOfType<TypeParameter>(node) != null;
  }

  /// Errors and their causes are opaque: Dart can throw any object, and the
  /// original is kept in an `error`, `cause` or `innerError` value. `Object`
  /// is acceptable for a parameter, field or variable whose name says so; in
  /// a multi-variable declaration every name must. `dynamic` is NOT allowed here.
  bool _isErrorValue(NamedType node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FormalParameter) {
        return _isErrorName(current.name?.lexeme);
      }

      if (current is VariableDeclarationList) {
        return current.variables.every((variable) => _isErrorName(variable.name.lexeme));
      }

      // Stop at declaration boundaries
      if (current is MethodDeclaration ||
          current is FunctionDeclaration ||
          current is ConstructorDeclaration ||
          current is ClassDeclaration) {
        return false;
      }

      current = current.parent;
    }
    return false;
  }

  bool _isErrorName(String? name) {
    if (name == null) return false;
    final lowerCaseName = name.toLowerCase();
    return lowerCaseName.contains('error') || lowerCaseName.contains('cause');
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
      if (rule._isAllowedObject(node)) return;
      rule.reportAtNode(node);
    }
  }
}
