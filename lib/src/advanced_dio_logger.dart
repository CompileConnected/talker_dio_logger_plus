import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logger_settings.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/utils/talker_compat.dart';

import 'models/http_log_data.dart';

/// Advanced Dio HTTP client logger with rich features.
///
/// Attach this interceptor to a [Dio] instance to automatically log
/// requests, responses, and errors to [Talker].
///
/// Features:
/// - cURL command generation (with option to hide sensitive data)
/// - Interactive JSON viewer with search
/// - Image preview support
/// - HTML preview support
/// - Large data truncation and download
/// - Response time tracking
class AdvancedDioLogger extends Interceptor {
  AdvancedDioLogger({Talker? talker, AdvancedDioLoggerSettings? settings}) {
    _talker = talker ?? Talker();
    this.settings = settings ?? AdvancedDioLoggerSettings();
    _talker.registerHttpLogKeys();
  }

  /// Key added to `RequestOptions.extra` to calculate response time.
  static const _requestTimestampKey = '_talker_dio_logger_ts_';

  late Talker _talker;

  /// Logger settings.
  late AdvancedDioLoggerSettings settings;

  /// The [Talker] instance used for logging.
  Talker get talker => _talker;

  /// Replace the current settings at runtime.
  void updateSettings(AdvancedDioLoggerSettings newSettings) {
    settings = newSettings;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (settings.enabled && settings.printResponseTime) {
      options.extra[_requestTimestampKey] =
          DateTime.now().millisecondsSinceEpoch;
    }

    super.onRequest(options, handler);

    if (!settings.enabled) return;
    if (!_shouldLog(settings.requestFilter, options)) return;

    _emitLog(
      uri: options.uri,
      type: AdvancedDioLogType.request,
      buildData: () => HttpLogDataFactory.fromRequest(options, settings),
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(response, handler);

    if (!settings.enabled) return;
    if (!_shouldLog(settings.responseFilter, response)) return;

    _emitLog(
      uri: response.requestOptions.uri,
      type: AdvancedDioLogType.response,
      buildData: () => HttpLogDataFactory.fromResponse(response, settings),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    super.onError(err, handler);

    if (!settings.enabled) return;
    if (!_shouldLog(settings.errorFilter, err)) return;

    _emitLog(
      uri: err.requestOptions.uri,
      type: AdvancedDioLogType.error,
      buildData: () => HttpLogDataFactory.fromError(err, settings),
    );
  }

  /// Runs [filter] safely. Returns `true` when the log should be emitted.
  ///
  /// If the user-provided filter throws, we default to logging the entry
  /// instead of crashing the app.
  bool _shouldLog<T>(bool Function(T)? filter, T value) {
    if (filter == null) return true;
    try {
      return filter(value);
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: filter error: $e\n$st');
      return true;
    }
  }

  /// Builds the log data and emits it through [_talker].
  ///
  /// [buildData] is called lazily so we skip expensive work when the
  /// logger is disabled or filtered out.
  void _emitLog({
    required Uri uri,
    required AdvancedDioLogType type,
    required HttpLogData Function() buildData,
  }) {
    try {
      final log = AdvancedDioLog(
        '$uri',
        type: type,
        settings: settings,
        httpLogData: buildData(),
      );
      _talker.logCustom(log);
    } catch (e, st) {
      debugPrint('AdvancedDioLogger: Failed to log $type: $e\n$st');
    }
  }
}
