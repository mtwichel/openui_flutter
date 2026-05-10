/// Pure-Dart core for the OpenUI Flutter port.
///
/// This is the only file consumers should import from `openui_core`. The
/// `src/` tree is private. AST node types and `ParseResult` are
/// exported but marked `@experimental` — their shape may change between v0.1
/// and v0.2.
library;

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
export 'src/eval/evaluator.dart' show BuiltinHandler, EvalContext, evaluate;
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
export 'src/state/store.dart' show Store;
