import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';

bool _isDynamic(DartType type) => type is DynamicType;

/// A quick fix that adds an explicit return type to functions/methods.
///
/// This fix analyzes the function body to infer the return type and inserts it
/// before the function name. For functions with no return statements,
/// it suggests `void` (or `Future<void>` for async functions).
class AddReturnTypeFix extends ResolvedCorrectionProducer {
  AddReturnTypeFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.addReturnType',
    DartFixKindPriority.standard,
    'Add explicit return type',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final targetNode = node;

    if (targetNode is FunctionDeclaration) {
      if (targetNode.externalKeyword != null) return;

      final body = targetNode.functionExpression.body;
      final typeString = _inferReturnType(body);
      if (typeString == null) return;

      final insertOffset = targetNode.isGetter && targetNode.propertyKeyword != null
          ? targetNode.propertyKeyword!.offset
          : targetNode.name.offset;

      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(insertOffset, '$typeString ');
      });
    } else if (targetNode is MethodDeclaration) {
      if (targetNode.isSetter) return;

      final body = targetNode.body;
      final typeString = _inferReturnType(body);
      if (typeString == null) return;

      final insertOffset = targetNode.isGetter && targetNode.propertyKeyword != null
          ? targetNode.propertyKeyword!.offset
          : targetNode.name.offset;

      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(insertOffset, '$typeString ');
      });
    } else if (targetNode is NamedType && targetNode.name.lexeme == 'dynamic') {
      // Error was reported at the return type annotation itself
      final parent = targetNode.parent;
      FunctionBody? body;
      if (parent is FunctionDeclaration) {
        body = parent.functionExpression.body;
      } else if (parent is MethodDeclaration) {
        body = parent.body;
      }
      if (body == null) return;

      final typeString = _inferReturnType(body);
      if (typeString == null) return;

      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          typeString,
        );
      });
    }
  }

  /// Infers the return type from a function body.
  String? _inferReturnType(FunctionBody body) {
    final isAsync = body.isAsynchronous;

    if (body is ExpressionFunctionBody) {
      final type = body.expression.staticType;
      return _formatReturnType(type, isAsync);
    }

    final visitor = _ReturnStatementVisitor();
    body.accept(visitor);

    if (!visitor.hasReturnWithValue) {
      return isAsync ? 'Future<void>' : 'void';
    }

    final returnedType = visitor.returnedType;
    return _formatReturnType(returnedType, isAsync);
  }

  /// Formats a DartType as a return type string.
  String? _formatReturnType(DartType? type, bool isAsync) {
    if (type == null || _isDynamic(type)) return null;

    final typeStr = type.getDisplayString();

    if (isAsync) {
      if (type.isDartAsyncFuture || type.isDartAsyncFutureOr) {
        return typeStr;
      }
      return 'Future<$typeStr>';
    }

    return typeStr;
  }
}

/// Visitor that collects information about return statements.
class _ReturnStatementVisitor extends RecursiveAstVisitor<void> {
  bool hasReturnWithValue = false;
  DartType? returnedType;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final expr = node.expression;
    if (expr != null) {
      hasReturnWithValue = true;
      returnedType ??= expr.staticType;
    }
    super.visitReturnStatement(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested functions
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    // Skip nested function declarations
  }
}
