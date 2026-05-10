// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// Per-element error boundary.
///
/// Wraps the child produced by [builder]. If the build of the child
/// throws, [ErrorBoundary] shows the last successfully built child and
/// reports the captured exception through [onError]. The next
/// successful build clears the cached child — Flutter's synchronous
/// build pipeline means a single non-throwing render is definitive, so
/// the JS reference's 3-frame counter (which exists to debounce React's
/// concurrent rendering) is not needed (Acceptance Gap A14).
///
/// Construction does not run [builder]; the builder is invoked inside
/// `build` where exceptions can be intercepted.
///
/// Marked `@experimental` per D12.
@experimental
class ErrorBoundary extends StatefulWidget {
  /// Creates an [ErrorBoundary].
  const ErrorBoundary({
    required this.statementId,
    required this.builder,
    required this.onError,
    super.key,
  });

  /// Statement id this boundary is wrapping. Surfaces through
  /// `OpenUIError.statementId` on capture.
  final String statementId;

  /// Produces the wrapped child. Invoked inside `build` so any
  /// synchronous exception is captured.
  final WidgetBuilder builder;

  /// Reports a captured exception. Always invoked synchronously after
  /// the failing build returns the cached child.
  final void Function(OpenUIError error) onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Widget? _lastSuccess;

  @override
  Widget build(BuildContext context) {
    try {
      final child = widget.builder(context);
      _lastSuccess = child;
      return child;
    } on Object catch (error, stackTrace) {
      final captured = _wrapAsOpenUiError(error, widget.statementId);
      widget.onError(captured);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'openui',
          context: ErrorDescription(
            'while building component for statement '
            '"${widget.statementId}"',
          ),
        ),
      );
      final fallback = _lastSuccess;
      if (fallback != null) return fallback;
      return const SizedBox.shrink();
    }
  }
}

OpenUIError _wrapAsOpenUiError(Object error, String statementId) {
  if (error is OpenUIError) {
    return error;
  }
  return EvaluationError(
    message: error.toString(),
    statementId: statementId,
  );
}
