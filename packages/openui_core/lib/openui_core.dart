/// Pure-Dart core for the OpenUI Flutter port.
///
/// This is the only file consumers should import from `openui_core`. The
/// `src/` tree is private. AST node types and `ParseResult` are
/// exported but marked `@experimental` — their shape may change between v0.1
/// and v0.2.
library;

export 'package:json_schema_builder/json_schema_builder.dart' show Schema;

export 'src/actions/actions.dart'
    show
        ActionEvent,
        ActionPlan,
        ActionStep,
        BuiltinActionType,
        ContinueConversationStep,
        CustomActionStep,
        OpenUrlStep,
        ResetStep,
        RunStep,
        SetStep,
        actionPlanFromAst,
        dispatchAction;
export 'src/errors/errors.dart'
    show
        AdapterMismatchError,
        CyclicStateError,
        EvaluationError,
        McpToolError,
        OpenUIError,
        ParseError,
        ToolNotFoundError,
        UnknownComponentError;
export 'src/eval/builtins.dart' show functionalBuiltins;
export 'src/eval/evaluator.dart' show BuiltinHandler, EvalContext, evaluate;
export 'src/library/library.dart'
    show
        Component,
        ComponentRender,
        Library,
        ReactiveAssign,
        evaluateElementProps,
        isReactiveAssign;
export 'src/merge/merge.dart' show mergeStatements;
export 'src/parse/parse.dart'
    show
        CompiledMeta,
        CompiledProgram,
        ParamMap,
        ParamSpec,
        ResolvedElement,
        parse;
export 'src/parser/lexer.dart' show LexException, Token, TokenKind, tokenize;
export 'src/parser/materialize.dart'
    show ElementNode, MaterializedResult, materialize;
export 'src/parser/parser.dart'
    show
        Argument,
        ArrayLit,
        AstNode,
        BinaryOp,
        BuiltinCall,
        CompCall,
        IndexAccess,
        Literal,
        MemberAccess,
        MutationCall,
        NullLiteral,
        ObjectEntry,
        ObjectLit,
        ParseException,
        Program,
        QueryCall,
        Reference,
        StateAssign,
        StateRef,
        Statement,
        StatementKind,
        Ternary,
        UnaryOp,
        autoClose,
        classifyStatement,
        parseExpression,
        parseProgram;
export 'src/parser/streaming.dart'
    show
        MutationDecl,
        ParseMeta,
        ParseResult,
        QueryDecl,
        StateDecl,
        StreamParser,
        createStreamingParser;
export 'src/prompt/prompt.dart' show generatePrompt;
export 'src/state/store.dart' show Store;
export 'src/tools/tools.dart' show Tool, ToolResult;
