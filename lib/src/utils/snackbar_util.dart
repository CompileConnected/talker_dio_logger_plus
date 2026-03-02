import 'package:flutter/material.dart';

/// Utility class for displaying snackbars consistently across the app.
class SnackBarUtil {
  SnackBarUtil._();

  /// Shows a basic snackbar with the given [message].
  ///
  /// Safe to call from async callbacks — checks [BuildContext.mounted]
  /// before accessing the [ScaffoldMessenger], so it is a no-op if the
  /// widget has already been disposed.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: textColor != null ? TextStyle(color: textColor) : null,
          ),
          backgroundColor: backgroundColor,
          duration: duration,
          action: action,
        ),
      );
  }

  /// Hides the currently visible snackbar, if any.
  ///
  /// No-op if [context] is no longer mounted.
  static void hide(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
