import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logger_settings.dart';
import 'package:talker_dio_logger_plus/src/models/content_type_detector.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/utils/data_truncator.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';
import 'package:talker_dio_logger_plus/src/utils/talker_compat.dart';

const _encoder = JsonEncoder.withIndent('  ');
const _hiddenValue = '*****';

/// Advanced HTTP Request Log with detailed data
class AdvancedDioRequestLog extends TalkerLog {
  AdvancedDioRequestLog(
    String super.message, {
    required this.requestOptions,
    required this.settings,
    required this.httpLogData,
  });

  final RequestOptions requestOptions;
  final AdvancedDioLoggerSettings settings;
  final HttpLogData httpLogData;

  @override
  AnsiPen get pen => settings.requestPen ?? (AnsiPen()..xterm(219));

  @override
  String get key => TalkerHttpKeys.httpRequest;

  @override
  LogLevel get logLevel => settings.logLevel;

  /// Get cURL command with hidden sensitive values
  String get curlCommandSafe => CurlGenerator.generateSafe(
    requestOptions,
    hiddenHeaders: settings.hiddenHeaders,
    hideAuthorizationValue: settings.hideAuthorizationValue,
  );

  /// Get full cURL command (with all values visible)
  String get curlCommandFull => CurlGenerator.generateFull(requestOptions);

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    final buffer = StringBuffer();
    buffer.write('[$title] [${requestOptions.method}] $message');

    final data = requestOptions.data;
    final headers = Map.from(requestOptions.headers);

    try {
      if (settings.printRequestData && data != null) {
        // Check if data should be truncated
        if (SizeCalculator.shouldTruncate(
          data,
          threshold: settings.truncateThreshold,
        )) {
          final truncationResult = DataTruncator.truncate(
            data,
            threshold: settings.truncateThreshold,
          );
          if (data is FormData) {
            buffer.write('\nData: ${_formatFormData(data)}');
          } else {
            buffer.write('\nData: ${_encoder.convert(truncationResult.data)}');
          }
          buffer.write(
            '\n[Truncated: ${SizeCalculator.formatBytes(truncationResult.originalSize)} - tap for full content]',
          );
        } else {
          if (data is FormData) {
            buffer.write('\nData: ${_formatFormData(data)}');
          } else {
            final prettyData = _encoder.convert(data);
            buffer.write('\nData: $prettyData');
          }
        }
      }

      if (settings.printRequestHeaders && headers.isNotEmpty) {
        _replaceHiddenHeaders(headers);
        final prettyHeaders = _encoder.convert(headers);
        buffer.write('\nHeaders: $prettyHeaders');
      }

      final extra = Map.from(requestOptions.extra);
      // Remove internal timestamp key
      extra.remove('_talker_dio_logger_ts_');
      if (settings.printRequestExtra && extra.isNotEmpty) {
        final prettyExtra = _encoder.convert(extra);
        buffer.write('\nExtra: $prettyExtra');
      }
    } catch (_) {
      // Handle conversion errors
    }
    return buffer.toString();
  }

  String _formatFormData(FormData data) {
    final formDataMap = <String, dynamic>{};
    for (var field in data.fields) {
      formDataMap[field.key] = field.value;
    }
    for (var file in data.files) {
      formDataMap[file.key] = {
        'filename': file.value.filename,
        'contentType': file.value.contentType.toString(),
        'bytes': file.value.length,
      };
    }
    return _encoder.convert(formDataMap);
  }

  void _replaceHiddenHeaders(Map<dynamic, dynamic> headers) {
    final lowerCaseHeaders = <String, String>{};
    headers.forEach((key, value) {
      lowerCaseHeaders[key.toLowerCase()] = key;
    });

    for (final hiddenHeader in settings.hiddenHeaders) {
      final lowerCaseHiddenHeader = hiddenHeader.toLowerCase();
      if (lowerCaseHeaders.containsKey(lowerCaseHiddenHeader)) {
        final originalHeader = lowerCaseHeaders[lowerCaseHiddenHeader]!;
        headers[originalHeader] = _hiddenValue;
      }
    }

    // Handle authorization header specially
    if (settings.hideAuthorizationValue) {
      const authKeys = ['authorization', 'x-auth-token'];
      for (final authKey in authKeys) {
        if (lowerCaseHeaders.containsKey(authKey)) {
          final originalKey = lowerCaseHeaders[authKey]!;
          final value = headers[originalKey]?.toString() ?? '';
          if (value.toLowerCase().startsWith('bearer ')) {
            headers[originalKey] = 'Bearer $_hiddenValue';
          } else {
            headers[originalKey] = _hiddenValue;
          }
        }
      }
    }
  }
}

/// Advanced HTTP Response Log with detailed data
class AdvancedDioResponseLog extends TalkerLog {
  AdvancedDioResponseLog(
    String message, {
    required this.response,
    required this.settings,
    required this.httpLogData,
  }) : responseTime = _getResponseTime(response.requestOptions),
       super(message);

  final Response<dynamic> response;
  final AdvancedDioLoggerSettings settings;
  final HttpLogData httpLogData;
  final int? responseTime;

  @override
  AnsiPen get pen => settings.responsePen ?? (AnsiPen()..xterm(46));

  @override
  String get key => TalkerHttpKeys.httpResponse;

  @override
  LogLevel get logLevel => settings.logLevel;

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    final buffer = StringBuffer();
    buffer.write('[$title] [${response.requestOptions.method}] $message');

    final responseMessage = response.statusMessage;
    final data = response.data;
    final headers = response.headers.map;

    buffer.write('\nStatus: ${response.statusCode}');

    if (settings.printResponseTime && responseTime != null) {
      buffer.write('\nTime: $responseTime ms');
    }

    if (settings.printResponseMessage && responseMessage != null) {
      buffer.write('\nMessage: $responseMessage');
    }

    // Add content type info
    buffer.write('\nContent-Type: ${httpLogData.contentType.name}');
    if (httpLogData.contentLength != null) {
      buffer.write(
        '\nSize: ${SizeCalculator.formatBytes(httpLogData.contentLength!)}',
      );
    }

    try {
      if (settings.printResponseData && data != null) {
        // Handle different content types
        if (httpLogData.isImage) {
          buffer.write(
            '\n[Image Data - ${SizeCalculator.formatBytes(httpLogData.approximateResponseSize)}]',
          );
          if (httpLogData.approximateResponseSize >
              settings.imagePreviewThreshold) {
            buffer.write('\n[Too large for preview - tap to view]');
          }
        } else if (httpLogData.isHtml) {
          buffer.write('\n[HTML Content - tap to preview]');
        } else if (httpLogData.isTruncated) {
          final truncationResult = DataTruncator.truncate(
            data,
            threshold: settings.truncateThreshold,
          );
          final prettyData =
              settings.responseDataConverter?.call(response) ??
              _encoder.convert(truncationResult.data);
          buffer.write('\nData: $prettyData');
          buffer.write(
            '\n[Truncated: ${SizeCalculator.formatBytes(truncationResult.originalSize)} - tap for full content]',
          );
        } else {
          final prettyData =
              settings.responseDataConverter?.call(response) ??
              _encoder.convert(data);
          buffer.write('\nData: $prettyData');
        }
      }

      if (settings.printResponseHeaders && headers.isNotEmpty) {
        final prettyHeaders = _encoder.convert(headers);
        buffer.write('\nHeaders: $prettyHeaders');
      }
    } catch (_) {
      // Handle conversion errors
    }
    return buffer.toString();
  }
}

/// Advanced HTTP Error Log with detailed data
class AdvancedDioErrorLog extends TalkerLog {
  AdvancedDioErrorLog(
    String title, {
    required this.dioException,
    required this.settings,
    required this.httpLogData,
  }) : responseTime = _getResponseTime(dioException.requestOptions),
       super(title);

  final DioException dioException;
  final AdvancedDioLoggerSettings settings;
  final HttpLogData httpLogData;
  final int? responseTime;

  @override
  AnsiPen get pen => settings.errorPen ?? (AnsiPen()..red());

  @override
  String get key => TalkerHttpKeys.httpError;

  @override
  LogLevel get logLevel => LogLevel.error;

  /// Get cURL command with hidden sensitive values
  String get curlCommandSafe => CurlGenerator.generateSafe(
    dioException.requestOptions,
    hiddenHeaders: settings.hiddenHeaders,
    hideAuthorizationValue: settings.hideAuthorizationValue,
  );

  /// Get full cURL command (with all values visible)
  String get curlCommandFull =>
      CurlGenerator.generateFull(dioException.requestOptions);

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    final buffer = StringBuffer();
    buffer.write('[$title] [${dioException.requestOptions.method}] $message');

    final responseMessage = dioException.message;
    final statusCode = dioException.response?.statusCode;
    final data = dioException.response?.data;
    final headers = dioException.response?.headers;

    if (statusCode != null) {
      buffer.write('\nStatus: $statusCode');
    }

    if (settings.printResponseTime && responseTime != null) {
      buffer.write('\nTime: $responseTime ms');
    }

    if (settings.printErrorMessage && responseMessage != null) {
      buffer.write('\nMessage: $responseMessage');
    }

    // Error type info
    buffer.write('\nError Type: ${dioException.type.name}');

    if (settings.printErrorData && data != null) {
      if (SizeCalculator.shouldTruncate(
        data,
        threshold: settings.truncateThreshold,
      )) {
        final truncationResult = DataTruncator.truncate(
          data,
          threshold: settings.truncateThreshold,
        );
        final prettyData = _encoder.convert(truncationResult.data);
        buffer.write('\nData: $prettyData');
        buffer.write(
          '\n[Truncated: ${SizeCalculator.formatBytes(truncationResult.originalSize)}]',
        );
      } else {
        final prettyData = _encoder.convert(data);
        buffer.write('\nData: $prettyData');
      }
    }

    if (settings.printErrorHeaders && !(headers?.isEmpty ?? true)) {
      final prettyHeaders = _encoder.convert(headers!.map);
      buffer.write('\nHeaders: $prettyHeaders');
    }
    return buffer.toString();
  }
}

/// Get response time from request options
int? _getResponseTime(RequestOptions options) {
  final triggerTime = options.extra['_talker_dio_logger_ts_'];
  if (triggerTime is int) {
    return DateTime.now().millisecondsSinceEpoch - triggerTime;
  }
  return null;
}

/// Create HttpLogData from request options
HttpLogData createRequestLogData(
  RequestOptions options,
  AdvancedDioLoggerSettings settings,
) {
  final queryParams = <String, dynamic>{};
  options.uri.queryParameters.forEach((key, value) {
    queryParams[key] = value;
  });

  dynamic requestBody = options.data;
  final dynamic fullRequestBody = options.data;
  var isRequestTruncated = false;

  if (requestBody != null &&
      SizeCalculator.shouldTruncate(
        requestBody,
        threshold: settings.truncateThreshold,
      )) {
    final result = DataTruncator.truncate(
      requestBody,
      threshold: settings.truncateThreshold,
    );
    requestBody = result.data;
    isRequestTruncated = true;
  }

  // Process headers to hide sensitive values
  final headers = Map<String, dynamic>.from(options.headers);
  _processHeaders(headers, settings);

  return HttpLogData(
    method: options.method,
    uri: options.uri,
    timestamp: DateTime.now(),
    requestHeaders: headers,
    requestBody: requestBody,
    fullRequestBody: fullRequestBody,
    requestQueryParams: queryParams.isNotEmpty ? queryParams : null,
    isRequestTruncated: isRequestTruncated,
    requestOptions: options,
  );
}

/// Create HttpLogData from response
HttpLogData createResponseLogData(
  Response response,
  AdvancedDioLoggerSettings settings,
) {
  final contentType = ContentTypeDetector.detectFromResponse(response);
  final contentLength = _getContentLength(response);

  dynamic responseBody = response.data;
  final dynamic fullResponseBody = response.data;
  var isResponseTruncated = false;
  Uint8List? imageData;

  // Handle image data
  if (contentType == HttpContentType.image) {
    if (response.data is List<int>) {
      imageData = Uint8List.fromList(response.data as List<int>);
    }
  }

  // Truncate large response data for display
  if (responseBody != null &&
      contentType != HttpContentType.image &&
      SizeCalculator.shouldTruncate(
        responseBody,
        threshold: settings.truncateThreshold,
      )) {
    final result = DataTruncator.truncate(
      responseBody,
      threshold: settings.truncateThreshold,
    );
    responseBody = result.data;
    isResponseTruncated = true;
  }

  // Process request headers
  final requestHeaders = Map<String, dynamic>.from(
    response.requestOptions.headers,
  );
  _processHeaders(requestHeaders, settings);

  final queryParams = <String, dynamic>{};
  response.requestOptions.uri.queryParameters.forEach((key, value) {
    queryParams[key] = value;
  });

  return HttpLogData(
    method: response.requestOptions.method,
    uri: response.requestOptions.uri,
    timestamp: DateTime.now(),
    requestHeaders: requestHeaders,
    requestBody: response.requestOptions.data,
    requestQueryParams: queryParams.isNotEmpty ? queryParams : null,
    responseHeaders: response.headers.map,
    responseBody: responseBody,
    fullResponseBody: fullResponseBody,
    statusCode: response.statusCode,
    statusMessage: response.statusMessage,
    responseTime: _getResponseTime(response.requestOptions),
    contentType: contentType,
    contentLength: contentLength,
    imageData: imageData,
    isResponseTruncated: isResponseTruncated,
    requestOptions: response.requestOptions,
    response: response,
  );
}

/// Create HttpLogData from error
HttpLogData createErrorLogData(
  DioException error,
  AdvancedDioLoggerSettings settings,
) {
  HttpContentType contentType = HttpContentType.unknown;
  int? contentLength;
  Uint8List? imageData;

  if (error.response != null) {
    contentType = ContentTypeDetector.detectFromResponse(error.response!);
    contentLength = _getContentLength(error.response!);

    if (contentType == HttpContentType.image &&
        error.response!.data is List<int>) {
      imageData = Uint8List.fromList(error.response!.data as List<int>);
    }
  }

  // Process request headers
  final requestHeaders = Map<String, dynamic>.from(
    error.requestOptions.headers,
  );
  _processHeaders(requestHeaders, settings);

  final queryParams = <String, dynamic>{};
  error.requestOptions.uri.queryParameters.forEach((key, value) {
    queryParams[key] = value;
  });

  return HttpLogData(
    method: error.requestOptions.method,
    uri: error.requestOptions.uri,
    timestamp: DateTime.now(),
    requestHeaders: requestHeaders,
    requestBody: error.requestOptions.data,
    requestQueryParams: queryParams.isNotEmpty ? queryParams : null,
    responseHeaders: error.response?.headers.map,
    responseBody: error.response?.data,
    fullResponseBody: error.response?.data,
    statusCode: error.response?.statusCode,
    statusMessage: error.response?.statusMessage,
    responseTime: _getResponseTime(error.requestOptions),
    error: error.message,
    contentType: contentType,
    contentLength: contentLength,
    imageData: imageData,
    requestOptions: error.requestOptions,
    response: error.response,
    dioException: error,
  );
}

/// Process headers to hide sensitive values
void _processHeaders(
  Map<String, dynamic> headers,
  AdvancedDioLoggerSettings settings,
) {
  final lowerCaseMap = <String, String>{};
  headers.forEach((key, value) {
    lowerCaseMap[key.toLowerCase()] = key;
  });

  for (final hiddenHeader in settings.hiddenHeaders) {
    final lowerCaseKey = hiddenHeader.toLowerCase();
    if (lowerCaseMap.containsKey(lowerCaseKey)) {
      final originalKey = lowerCaseMap[lowerCaseKey]!;
      headers[originalKey] = _hiddenValue;
    }
  }

  if (settings.hideAuthorizationValue) {
    const authKeys = ['authorization', 'x-auth-token'];
    for (final authKey in authKeys) {
      if (lowerCaseMap.containsKey(authKey)) {
        final originalKey = lowerCaseMap[authKey]!;
        final value = headers[originalKey]?.toString() ?? '';
        if (value.toLowerCase().startsWith('bearer ')) {
          headers[originalKey] = 'Bearer $_hiddenValue';
        } else {
          headers[originalKey] = _hiddenValue;
        }
      }
    }
  }
}

/// Get content length from response
int? _getContentLength(Response response) {
  final contentLengthHeader = response.headers.value('content-length');
  if (contentLengthHeader != null) {
    return int.tryParse(contentLengthHeader);
  }
  return null;
}
