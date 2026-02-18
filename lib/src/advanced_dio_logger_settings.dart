import 'package:dio/dio.dart';
import 'package:talker_dio_logger_plus/src/utils/file_saver_interface.dart';
import 'package:talker_dio_logger_plus/src/utils/talker_compat.dart';

/// Constants for the advanced Dio logger
///
/// Why centralized constants: Makes configuration easier to understand
/// and prevents magic numbers throughout the codebase.
class AdvancedDioLoggerConstants {
  /// Default truncation threshold (100KB)
  ///
  /// Why 100KB: Balances readability with performance. Most API responses
  /// that developers need to debug are under this threshold. Larger
  /// responses typically indicate file downloads or malformed data.
  static const int defaultTruncateThreshold = 100 * 1024;

  /// Default maximum display size (1MB)
  ///
  /// Why 1MB: Prevents memory issues when rendering large responses.
  /// Responses larger than this are typically binary data that shouldn't
  /// be displayed as text anyway.
  static const int defaultMaxDisplaySize = 1024 * 1024;

  /// Default image preview threshold (500KB)
  ///
  /// Why 500KB: Images under this size can be decoded and displayed
  /// inline without noticeable lag. Larger images should be viewed
  /// in a separate screen with proper memory management.
  static const int defaultImagePreviewThreshold = 500 * 1024;

  /// Default max inline JSON lines
  ///
  /// Why 20 lines: Provides enough context to understand the response
  /// without overwhelming the log list. Users can tap for full view.
  static const int defaultMaxInlineJsonLines = 20;

  /// Default width for soft wrapping string values in JSON viewer (in logical pixels)
  ///
  /// When set, long string values in the JSON viewer will be soft wrapped
  /// at this width. Only affects string values, not keys or structure.
  /// Set to null to disable soft wrapping (default).
  static const double? defaultJsonSoftWrapTextValueAtWidth = null;

  /// Default hidden headers for security
  ///
  /// Why these headers: Most common authentication headers that could
  /// expose credentials if logged or shared.
  static const Set<String> defaultHiddenHeaders = {
    'authorization',
    'x-api-key',
    'api-key',
  };
}

/// Settings for the advanced Dio logger
///
/// This class provides comprehensive configuration options for HTTP logging,
/// including security features, display settings, and filtering capabilities.
///
/// ## Quick Start
///
/// ```dart
/// // Use defaults for development
/// final logger = AdvancedDioLogger(
///   settings: const AdvancedDioLoggerSettings(),
/// );
///
/// // Production-safe settings
/// final logger = AdvancedDioLogger(
///   settings: AdvancedDioLoggerSettings.production(),
/// );
/// ```
///
/// ## Security Considerations
///
/// By default, the logger hides common authentication headers like
/// `Authorization` and `x-api-key`. In production, consider:
/// - Setting `hideAuthorizationValue: true` (default)
/// - Adding custom sensitive headers to `hiddenHeaders`
/// - Using `requestFilter` to exclude sensitive endpoints
class AdvancedDioLoggerSettings {
  const AdvancedDioLoggerSettings({
    this.enabled = true,
    this.logLevel = LogLevel.debug,
    this.printRequestData = true,
    this.printRequestHeaders = true,
    this.printRequestExtra = false,
    this.printResponseData = true,
    this.printResponseHeaders = true,
    this.printResponseMessage = true,
    this.printResponseTime = true,
    this.printErrorData = true,
    this.printErrorHeaders = true,
    this.printErrorMessage = true,
    this.hiddenHeaders = AdvancedDioLoggerConstants.defaultHiddenHeaders,
    this.hideAuthorizationValue = true,
    this.truncateThreshold =
        AdvancedDioLoggerConstants.defaultTruncateThreshold,
    this.maxDisplaySize = AdvancedDioLoggerConstants.defaultMaxDisplaySize,
    this.imagePreviewThreshold =
        AdvancedDioLoggerConstants.defaultImagePreviewThreshold,
    this.maxInlineJsonLines =
        AdvancedDioLoggerConstants.defaultMaxInlineJsonLines,
    this.jsonSoftWrapTextValueAtWidth =
        AdvancedDioLoggerConstants.defaultJsonSoftWrapTextValueAtWidth,
    this.requestPen,
    this.responsePen,
    this.errorPen,
    this.requestFilter,
    this.responseFilter,
    this.errorFilter,
    this.responseDataConverter,
    this.enableCurlGeneration = true,
    this.enableJsonViewer = true,
    this.enableImagePreview = true,
    this.enableHtmlPreview = true,
    this.enableDownload = true,
    this.fileSaver,
  });

  /// Create production-safe settings with minimal logging
  ///
  /// Why: In production, you typically want less verbose logging
  /// with maximum security to prevent credential exposure.
  factory AdvancedDioLoggerSettings.production() {
    return const AdvancedDioLoggerSettings(
      printRequestData: false,
      printRequestHeaders: false,
      printResponseData: false,
      printResponseHeaders: false,
      hideAuthorizationValue: true,
      logLevel: LogLevel.info,
    );
  }

  /// Create debug settings with maximum verbosity
  ///
  /// Why: During development, you want all available information
  /// to debug issues effectively.
  factory AdvancedDioLoggerSettings.debug() {
    return const AdvancedDioLoggerSettings(
      printRequestData: true,
      printRequestHeaders: true,
      printRequestExtra: true,
      printResponseData: true,
      printResponseHeaders: true,
      printResponseTime: true,
      logLevel: LogLevel.debug,
    );
  }

  /// Enable/disable the logger
  ///
  /// Set to `false` to completely disable logging without removing
  /// the interceptor from Dio.
  final bool enabled;

  /// Log level for all logs
  ///
  /// Controls which logs appear in the console based on Talker's
  /// log level filtering.
  final LogLevel logLevel;

  /// Print request body
  ///
  /// Warning: May expose sensitive data. Consider filtering
  /// sensitive endpoints with `requestFilter`.
  final bool printRequestData;

  /// Print request headers
  ///
  /// Headers in `hiddenHeaders` will be masked.
  final bool printRequestHeaders;

  /// Print request extra data (Dio's extra field)
  final bool printRequestExtra;

  /// Print response body
  ///
  /// Large responses will be truncated based on `truncateThreshold`.
  final bool printResponseData;

  /// Print response headers
  final bool printResponseHeaders;

  /// Print response status message
  final bool printResponseMessage;

  /// Print response time in milliseconds
  final bool printResponseTime;

  /// Print error body
  final bool printErrorData;

  /// Print error headers
  final bool printErrorHeaders;

  /// Print error message
  final bool printErrorMessage;

  /// Headers to hide (case-insensitive)
  ///
  /// Values of these headers will be replaced with `*****`.
  /// This is a security feature to prevent credential exposure
  /// when sharing logs.
  final Set<String> hiddenHeaders;

  /// Hide authorization header value
  ///
  /// When `true`, shows `Bearer *****` instead of the actual token.
  /// Highly recommended to keep enabled in production.
  final bool hideAuthorizationValue;

  /// Data size threshold for truncation (in bytes)
  ///
  /// Responses larger than this will be truncated in the log list
  /// but full content is available in the detail view.
  final int truncateThreshold;

  /// Maximum data size to display (in bytes)
  ///
  /// Data larger than this requires download to view.
  final int maxDisplaySize;

  /// Image size threshold for inline preview (in bytes)
  ///
  /// Images smaller than this show inline; larger images
  /// require tapping to view.
  final int imagePreviewThreshold;

  /// Maximum JSON lines to show inline
  final int maxInlineJsonLines;

  /// Width at which to soft wrap string values in JSON viewer (in logical pixels)
  ///
  /// When set, long string values in the JSON viewer will be constrained
  /// to this width and soft wrapped. Only affects string values, not keys
  /// or JSON structure.
  ///
  /// Set to `null` to disable soft wrapping (default - allows horizontal scroll).
  ///
  /// Example values:
  /// - `300` - Tight wrapping for narrow screens
  /// - `500` - Medium wrapping
  /// - `null` - No wrapping (horizontal scroll for long values)
  final double? jsonSoftWrapTextValueAtWidth;

  /// Custom pen for request logs
  final AnsiPen? requestPen;

  /// Custom pen for response logs
  final AnsiPen? responsePen;

  /// Custom pen for error logs
  final AnsiPen? errorPen;

  /// Filter for requests
  ///
  /// Return `false` to skip logging this request.
  /// Useful for excluding health checks or sensitive endpoints.
  ///
  /// Example:
  /// ```dart
  /// requestFilter: (options) {
  ///   // Skip logging for health check endpoints
  ///   return !options.path.contains('/health');
  /// }
  /// ```
  final bool Function(RequestOptions options)? requestFilter;

  /// Filter for responses
  ///
  /// Return `false` to skip logging this response.
  final bool Function(Response response)? responseFilter;

  /// Filter for errors
  ///
  /// Return `false` to skip logging this error.
  final bool Function(DioException exception)? errorFilter;

  /// Custom response data converter
  ///
  /// Transform response data before logging.
  /// Useful for custom serialization or sanitization.
  final String Function(Response response)? responseDataConverter;

  /// Enable cURL command generation
  ///
  /// When enabled, users can copy requests as cURL commands.
  final bool enableCurlGeneration;

  /// Enable interactive JSON viewer in detail view
  final bool enableJsonViewer;

  /// Enable image preview for image responses
  final bool enableImagePreview;

  /// Enable HTML preview for HTML responses
  final bool enableHtmlPreview;

  /// Enable download/share functionality
  final bool enableDownload;

  /// Custom file saver implementation
  ///
  /// If not provided, uses [DefaultFileSaver] which requires
  /// path_provider, archive, and share_plus packages.
  ///
  /// Provide your own implementation of [FileSaverInterface] to:
  /// - Use different file storage/sharing mechanisms
  /// - Avoid including the default dependencies
  /// - Use [NoOpFileSaver] to disable file operations entirely
  ///
  /// Example:
  /// ```dart
  /// // Disable file saving
  /// settings: AdvancedDioLoggerSettings(
  ///   fileSaver: const NoOpFileSaver(),
  /// )
  ///
  /// // Custom implementation
  /// settings: AdvancedDioLoggerSettings(
  ///   fileSaver: MyCustomFileSaver(),
  /// )
  /// ```
  final FileSaverInterface? fileSaver;

  /// Copy with method for immutable updates
  AdvancedDioLoggerSettings copyWith({
    bool? enabled,
    LogLevel? logLevel,
    bool? printRequestData,
    bool? printRequestHeaders,
    bool? printRequestExtra,
    bool? printResponseData,
    bool? printResponseHeaders,
    bool? printResponseMessage,
    bool? printResponseTime,
    bool? printErrorData,
    bool? printErrorHeaders,
    bool? printErrorMessage,
    Set<String>? hiddenHeaders,
    bool? hideAuthorizationValue,
    int? truncateThreshold,
    int? maxDisplaySize,
    int? imagePreviewThreshold,
    int? maxInlineJsonLines,
    double? jsonSoftWrapTextValueAtWidth,
    AnsiPen? requestPen,
    AnsiPen? responsePen,
    AnsiPen? errorPen,
    bool Function(RequestOptions options)? requestFilter,
    bool Function(Response response)? responseFilter,
    bool Function(DioException exception)? errorFilter,
    String Function(Response response)? responseDataConverter,
    bool? enableCurlGeneration,
    bool? enableJsonViewer,
    bool? enableImagePreview,
    bool? enableHtmlPreview,
    bool? enableDownload,
    FileSaverInterface? fileSaver,
  }) {
    return AdvancedDioLoggerSettings(
      enabled: enabled ?? this.enabled,
      logLevel: logLevel ?? this.logLevel,
      printRequestData: printRequestData ?? this.printRequestData,
      printRequestHeaders: printRequestHeaders ?? this.printRequestHeaders,
      printRequestExtra: printRequestExtra ?? this.printRequestExtra,
      printResponseData: printResponseData ?? this.printResponseData,
      printResponseHeaders: printResponseHeaders ?? this.printResponseHeaders,
      printResponseMessage: printResponseMessage ?? this.printResponseMessage,
      printResponseTime: printResponseTime ?? this.printResponseTime,
      printErrorData: printErrorData ?? this.printErrorData,
      printErrorHeaders: printErrorHeaders ?? this.printErrorHeaders,
      printErrorMessage: printErrorMessage ?? this.printErrorMessage,
      hiddenHeaders: hiddenHeaders ?? this.hiddenHeaders,
      hideAuthorizationValue:
          hideAuthorizationValue ?? this.hideAuthorizationValue,
      truncateThreshold: truncateThreshold ?? this.truncateThreshold,
      maxDisplaySize: maxDisplaySize ?? this.maxDisplaySize,
      imagePreviewThreshold:
          imagePreviewThreshold ?? this.imagePreviewThreshold,
      maxInlineJsonLines: maxInlineJsonLines ?? this.maxInlineJsonLines,
      jsonSoftWrapTextValueAtWidth:
          jsonSoftWrapTextValueAtWidth ?? this.jsonSoftWrapTextValueAtWidth,
      requestPen: requestPen ?? this.requestPen,
      responsePen: responsePen ?? this.responsePen,
      errorPen: errorPen ?? this.errorPen,
      requestFilter: requestFilter ?? this.requestFilter,
      responseFilter: responseFilter ?? this.responseFilter,
      errorFilter: errorFilter ?? this.errorFilter,
      responseDataConverter:
          responseDataConverter ?? this.responseDataConverter,
      enableCurlGeneration: enableCurlGeneration ?? this.enableCurlGeneration,
      enableJsonViewer: enableJsonViewer ?? this.enableJsonViewer,
      enableImagePreview: enableImagePreview ?? this.enableImagePreview,
      enableHtmlPreview: enableHtmlPreview ?? this.enableHtmlPreview,
      enableDownload: enableDownload ?? this.enableDownload,
      fileSaver: fileSaver ?? this.fileSaver,
    );
  }
}
