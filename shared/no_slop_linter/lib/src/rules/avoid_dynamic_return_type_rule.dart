import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that requires explicit non-dynamic return types on functions.
///
/// Functions and methods should always declare an explicit return type.
/// Using implicit or dynamic return types reduces type safety and can hide bugs.
///
/// Examples that trigger this rule:
/// - `foo() { }` - implicit return type
/// - `dynamic bar() { }` - explicit dynamic return type
/// - `get value { }` - getter without return type
///
/// Valid examples:
/// - `void foo() { }` - explicit void
/// - `String bar() => '';` - explicit String
/// - `Future<int> baz() async => 0;` - explicit `Future<int>`
/// - `set value(x) => _v = x;` - setters are skipped (implicitly void)
/// - `external dynamic foo();` - external functions (JS interop) are skipped
class AvoidDynamicReturnTypeRule extends NoSlopRule {
  AvoidDynamicReturnTypeRule()
      : super(name: code.lowerCaseName, description: 'Requires explicit non-dynamic return types.');

  static const code = LintCode(
    'avoid_dynamic_return_type',
    'Function has implicit or dynamic return type.',
    correctionMessage: 'Add an explicit return type annotation.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this);
    registry.addFunctionDeclaration(this, visitor);
    registry.addMethodDeclaration(this, visitor);
  }

  void _checkReturnType({
    required TypeAnnotation? returnType,
    required AstNode functionNode,
  }) {
    // No explicit return type annotation = implicit dynamic
    if (returnType == null) {
      reportAtNode(functionNode);
      return;
    }

    // Explicit "dynamic" return type - check if the type name is "dynamic"
    if (returnType is NamedType && returnType.name.lexeme == 'dynamic') {
      reportAtNode(returnType);
      return;
    }
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidDynamicReturnTypeRule rule;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.externalKeyword != null) return;

    rule._checkReturnType(
      returnType: node.returnType,
      functionNode: node,
    );
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.isSetter) return;
    if (node.externalKeyword != null) return;

    rule._checkReturnType(
      returnType: node.returnType,
      functionNode: node,
    );
  }
}
