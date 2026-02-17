import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logger_settings.dart';

/// Advanced Dio HTTP client logger with rich features
///
/// Features:
/// - cURL command generation (with option to hide sensitive data)
/// - Interactive JSON viewer with search
/// - Image preview support
/// - HTML preview support
/// - Large data truncation and download
/// - Response time tracking
class AdvancedDioLogger extends Interceptor {
  AdvancedDioLogger({
    Talker? talker,
    this.settings = const AdvancedDioLoggerSettings(),
  }) {
    _talker = talker ?? Talker();
    _talker.settings.registerKeys([
      TalkerKey.httpRequest,
      TalkerKey.httpResponse,
      TalkerKey.httpError,
    ]);
  }

  /// Timestamp key for response time calculation
  static const kTimeStampKey = '_talker_dio_logger_ts_';

  late Talker _talker;

  /// Logger settings
  AdvancedDioLoggerSettings settings;

  /// Get the Talker instance
  Talker get talker => _talker;

  /// Update settings
  void updateSettings(AdvancedDioLoggerSettings newSettings) {
    settings = newSettings;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Add timestamp for response time calculation
    if (settings.enabled && settings.printResponseTime) {
      options.extra[kTimeStampKey] = DateTime.now().millisecondsSinceEpoch;
    }

    super.onRequest(options, handler);

    if (!settings.enabled) return;

    // Apply request filter with error handling
    // Why: User-provided filter can throw - we shouldn't crash the app
    bool accepted;
    try {
      accepted = settings.requestFilter?.call(options) ?? true;
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: requestFilter error: $e\n$st');
      accepted = true; // Default to logging on filter error
    }
    if (!accepted) return;

    try {
      final message = '${options.uri}';
      final httpLogData = createRequestLogData(options, settings);
      final httpLog = AdvancedDioRequestLog(
        message,
        requestOptions: options,
        settings: settings,
        httpLogData: httpLogData,
      );
      _talker.logCustom(httpLog);
    } catch (e, st) {
      // Never crash the app due to logging errors
      debugPrint('AdvancedDioLogger: Failed to log request: $e\n$st');
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(response, handler);

    if (!settings.enabled) return;

    // Apply response filter with error handling
    bool accepted;
    try {
      accepted = settings.responseFilter?.call(response) ?? true;
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: responseFilter error: $e\n$st');
      accepted = true;
    }
    if (!accepted) return;

    try {
      final message = '${response.requestOptions.uri}';
      final httpLogData = createResponseLogData(response, settings);
      final httpLog = AdvancedDioResponseLog(
        message,
        response: response,
        settings: settings,
        httpLogData: httpLogData,
      );
      _talker.logCustom(httpLog);
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: Failed to log response: $e\n$st');
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    super.onError(err, handler);

    if (!settings.enabled) return;

    // Apply error filter with error handling
    bool accepted;
    try {
      accepted = settings.errorFilter?.call(err) ?? true;
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: errorFilter error: $e\n$st');
      accepted = true;
    }
    if (!accepted) return;

    try {
      final message = '${err.requestOptions.uri}';
      final httpLogData = createErrorLogData(err, settings);
      final httpErrorLog = AdvancedDioErrorLog(
        message,
        dioException: err,
        settings: settings,
        httpLogData: httpLogData,
      );
      _talker.logCustom(httpErrorLog);
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: Failed to log error: $e\n$st');
    }
  }
}

