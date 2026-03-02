import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:talker_dio_logger_plus/src/utils/snackbar_util.dart';

/// Minimal utility for copying text to the clipboard.
class ClipboardUtil {
  ClipboardUtil._();

  /// Copies [text] to the clipboard and shows a [snackBarMessage] if
  /// [context] is provided and still mounted.
  static Future<void> copy(
    String text, {
    BuildContext? context,
    String snackBarMessage = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context != null) {
      SnackBarUtil.show(context, snackBarMessage);
    }
  }
}
