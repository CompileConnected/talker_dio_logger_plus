import 'dart:typed_data';

import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';

/// Abstract interface for file saving and sharing operations.
///
/// Implement this interface to provide custom file saving logic,
/// or use the default [DefaultFileSaver] which uses path_provider,
/// archive, and share_plus packages.
///
/// Example custom implementation:
/// ```dart
/// class MyFileSaver implements FileSaverInterface {
///   @override
///   Future<String?> saveToFile({
///     required String filename,
///     required dynamic data,
///     String? directory,
///   }) async {
///     // Your custom implementation
///   }
///   // ... implement other methods
/// }
/// ```
abstract class FileSaverInterface {
  /// Save data to file and return the file path.
  ///
  /// - `filename` - Name of the file to save
  /// - `data` - Data to save (can be Uint8List, List of int, String, or any JSON-serializable object)
  /// - `directory` - Optional directory path, uses default if not provided
  ///
  /// Returns the file path if successful, null otherwise.
  Future<String?> saveToFile({
    required String filename,
    required dynamic data,
    String? directory,
  });

  /// Save HTTP log data to a ZIP file.
  ///
  /// [logData] - The HTTP log data to save
  /// [filename] - Optional custom filename
  ///
  /// Returns the ZIP file path if successful, null otherwise.
  Future<String?> saveHttpLogToZip(HttpLogData logData, {String? filename});

  /// Share a file using the system share dialog.
  ///
  /// [filepath] - Path to the file to share
  /// [subject] - Optional subject for the share
  /// [text] - Optional text to include with the share
  Future<void> shareFile({
    required String filepath,
    String? subject,
    String? text,
  });

  /// Share text content using the system share dialog.
  ///
  /// [text] - Text to share
  /// [subject] - Optional subject for the share
  Future<void> shareText(String text, {String? subject});

  /// Save HTTP log and share it.
  ///
  /// [logData] - The HTTP log data to save and share
  Future<void> saveAndShareHttpLog(HttpLogData logData);

  /// Convert data to Uint8List bytes.
  ///
  /// [data] - Data to convert
  ///
  /// Returns Uint8List if conversion is possible, null otherwise.
  Uint8List? getBytes(dynamic data);
}
