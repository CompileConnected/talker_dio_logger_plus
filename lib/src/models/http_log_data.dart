import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Content type enumeration for HTTP responses
enum HttpContentType {
  json,
  html,
  xml,
  text,
  image,
  binary,
  file,
  unknown,
}

/// Model class to hold detailed HTTP log data
class HttpLogData {
  HttpLogData({
    required this.method,
    required this.uri,
    required this.timestamp,
    this.requestHeaders,
    this.requestBody,
    this.requestQueryParams,
    this.responseHeaders,
    this.responseBody,
    this.statusCode,
    this.statusMessage,
    this.responseTime,
    this.error,
    this.contentType = HttpContentType.unknown,
    this.contentLength,
    this.imageData,
    this.isRequestTruncated = false,
    this.isResponseTruncated = false,
    this.fullRequestBody,
    this.fullResponseBody,
    this.requestOptions,
    this.response,
    this.dioException,
  });

  final String method;
  final Uri uri;
  final DateTime timestamp;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final Map<String, dynamic>? requestQueryParams;
  final Map<String, List<String>>? responseHeaders;
  final dynamic responseBody;
  final int? statusCode;
  final String? statusMessage;
  final int? responseTime;
  final String? error;
  final HttpContentType contentType;
  final int? contentLength;
  final Uint8List? imageData;
  final bool isRequestTruncated;
  final bool isResponseTruncated;
  final dynamic fullRequestBody;
  final dynamic fullResponseBody;

  // Original Dio objects for advanced operations
  final RequestOptions? requestOptions;
  final Response<dynamic>? response;
  final DioException? dioException;

  /// Returns true if response is an image
  bool get isImage => contentType == HttpContentType.image;

  /// Returns true if response is HTML
  bool get isHtml => contentType == HttpContentType.html;

  /// Returns true if response is JSON
  bool get isJson => contentType == HttpContentType.json;

  /// Returns true if response is text based
  bool get isTextBased => [
        HttpContentType.json,
        HttpContentType.html,
        HttpContentType.xml,
        HttpContentType.text,
      ].contains(contentType);

  /// Returns true if the data is too large and truncated
  bool get isTruncated => isRequestTruncated || isResponseTruncated;

  /// Calculate approximate size of the response
  int get approximateResponseSize {
    if (contentLength != null && contentLength! > 0) {
      return contentLength!;
    }
    if (responseBody == null) return 0;
    if (responseBody is String) return (responseBody as String).length;
    if (responseBody is List<int>) return (responseBody as List<int>).length;
    if (imageData != null) return imageData!.length;
    return responseBody.toString().length;
  }

  /// Get formatted URL
  String get formattedUrl => uri.toString();

  /// Get the path only
  String get path => uri.path;

  /// Copy with method
  HttpLogData copyWith({
    String? method,
    Uri? uri,
    DateTime? timestamp,
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    Map<String, dynamic>? requestQueryParams,
    Map<String, List<String>>? responseHeaders,
    dynamic responseBody,
    int? statusCode,
    String? statusMessage,
    int? responseTime,
    String? error,
    HttpContentType? contentType,
    int? contentLength,
    Uint8List? imageData,
    bool? isRequestTruncated,
    bool? isResponseTruncated,
    dynamic fullRequestBody,
    dynamic fullResponseBody,
    RequestOptions? requestOptions,
    Response<dynamic>? response,
    DioException? dioException,
  }) {
    return HttpLogData(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      timestamp: timestamp ?? this.timestamp,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      requestQueryParams: requestQueryParams ?? this.requestQueryParams,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      responseTime: responseTime ?? this.responseTime,
      error: error ?? this.error,
      contentType: contentType ?? this.contentType,
      contentLength: contentLength ?? this.contentLength,
      imageData: imageData ?? this.imageData,
      isRequestTruncated: isRequestTruncated ?? this.isRequestTruncated,
      isResponseTruncated: isResponseTruncated ?? this.isResponseTruncated,
      fullRequestBody: fullRequestBody ?? this.fullRequestBody,
      fullResponseBody: fullResponseBody ?? this.fullResponseBody,
      requestOptions: requestOptions ?? this.requestOptions,
      response: response ?? this.response,
      dioException: dioException ?? this.dioException,
    );
  }
}

