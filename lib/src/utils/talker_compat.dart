/// Talker Compatibility Layer
///
/// This file provides a compatibility layer for different versions of the
/// talker package. It handles breaking changes between major versions and
/// provides a consistent API for the rest of the codebase.
///
/// Supported versions:
/// - talker ^4.5.0 (uses string keys)
/// - talker ^5.0.0+ (uses TalkerKey enum and registerKeys)
///
/// Usage:
/// Instead of importing 'package:talker/talker.dart' directly,
/// import this file to get version-independent access to Talker APIs.
library;

import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';

// Re-export all commonly used Talker types
export 'package:talker/talker.dart'
    show Talker, TalkerLog, TalkerData, AnsiPen, LogLevel, TimeFormat;

/// Cached result of Talker version detection
bool? _isTalker5OrHigher;

/// Detect if we're running Talker 5.x or higher
///
/// Uses reflection-like approach by checking if registerKeys method exists
bool _detectTalker5() {
  if (_isTalker5OrHigher != null) return _isTalker5OrHigher!;

  try {
    // If TalkerSettings has registerKeys method, we're on 5.x+
    // We use dynamic to avoid compile-time errors on 4.x
    final settings = TalkerSettings();
    final dynamic dynamicSettings = settings;
    // This will throw if registerKeys doesn't exist
    dynamicSettings.registerKeys as Function;
    _isTalker5OrHigher = true;
  } catch (_) {
    _isTalker5OrHigher = false;
  }
  return _isTalker5OrHigher!;
}

/// HTTP Log key constants
///
/// These constants provide consistent log keys across different Talker versions.
/// In Talker 5.x, these match TalkerKey enum values.
/// In Talker 4.x, these are used directly as string keys.
abstract class TalkerHttpKeys {
  /// Key for HTTP request logs
  static const String httpRequest = 'http-request';

  /// Key for HTTP response logs
  static const String httpResponse = 'http-response';

  /// Key for HTTP error logs
  static const String httpError = 'http-error';
}

/// Extension to add version-compatible methods to Talker
extension TalkerCompat on Talker {
  /// Registers HTTP log keys with Talker settings (if supported)
  ///
  /// Automatically detects Talker version and calls the appropriate API:
  /// - Talker 5.x+: Calls settings.registerKeys() with TalkerKey values
  /// - Talker 4.x: No-op (registerKeys doesn't exist)
  void registerHttpLogKeys() {
    if (!_detectTalker5()) {
      // Talker 4.x - registerKeys doesn't exist, keys work via string matching
      return;
    }

    try {
      // Talker 5.x+ - use dynamic to call registerKeys
      // This avoids compile-time errors when building with Talker 4.x
      final dynamic dynamicSettings = settings;
      dynamicSettings.registerKeys([
        'http-request',
        'http-response',
        'http-error',
      ]);
    } catch (e) {
      // Silently fail if something goes wrong
      debugPrint('TalkerCompat: Failed to register HTTP keys: $e');
    }
  }
}

/// Mixin providing common log key functionality
///
/// Use this mixin in custom TalkerLog subclasses to get consistent
/// key handling across Talker versions.
mixin HttpLogKeyMixin {
  /// Get the appropriate key for request logs
  String get requestKey => TalkerHttpKeys.httpRequest;

  /// Get the appropriate key for response logs
  String get responseKey => TalkerHttpKeys.httpResponse;

  /// Get the appropriate key for error logs
  String get errorKey => TalkerHttpKeys.httpError;
}

/// Default AnsiPen configurations for HTTP logs
///
/// Provides consistent styling across the application and
/// makes it easy to customize colors in one place.
abstract class TalkerHttpPens {
  /// Default pen for HTTP request logs (pink/magenta)
  static AnsiPen get request => AnsiPen()..xterm(219);

  /// Default pen for HTTP response logs (green)
  static AnsiPen get response => AnsiPen()..xterm(46);

  /// Default pen for HTTP error logs (red)
  static AnsiPen get error => AnsiPen()..red();

  /// Pen for success status codes (2xx)
  static AnsiPen get success => AnsiPen()..green();

  /// Pen for redirect status codes (3xx)
  static AnsiPen get redirect => AnsiPen()..yellow();

  /// Pen for client error status codes (4xx)
  static AnsiPen get clientError => AnsiPen()..xterm(208); // Orange

  /// Pen for server error status codes (5xx)
  static AnsiPen get serverError => AnsiPen()..red();

  /// Get appropriate pen based on HTTP status code
  static AnsiPen forStatusCode(int? statusCode) {
    if (statusCode == null) return error;
    if (statusCode >= 200 && statusCode < 300) return success;
    if (statusCode >= 300 && statusCode < 400) return redirect;
    if (statusCode >= 400 && statusCode < 500) return clientError;
    return serverError;
  }
}

/// Helper to check if a TalkerData represents an HTTP log
extension TalkerDataHttpExt on TalkerData {
  /// Check if this log is an HTTP request
  bool get isHttpRequest => key == TalkerHttpKeys.httpRequest;

  /// Check if this log is an HTTP response
  bool get isHttpResponse => key == TalkerHttpKeys.httpResponse;

  /// Check if this log is an HTTP error
  bool get isHttpError => key == TalkerHttpKeys.httpError;

  /// Check if this log is any HTTP-related log
  bool get isHttpLog => isHttpRequest || isHttpResponse || isHttpError;
}
