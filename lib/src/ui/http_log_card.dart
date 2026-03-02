import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/ui/image_preview.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';
import 'package:talker_dio_logger_plus/src/utils/status_color.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../talker_dio_logger_plus.dart';

/// Custom HTTP log card widget with advanced features
class HttpLogCard extends StatefulWidget {
  const HttpLogCard({
    super.key,
    required this.data,
    this.onCopyTap,
    this.onTap,
    this.expanded = true,
    this.margin,
    this.theme = const TalkerScreenTheme(),
  });

  final TalkerData data;
  final VoidCallback? onCopyTap;
  final VoidCallback? onTap;
  final bool expanded;
  final EdgeInsets? margin;

  /// Theme configuration for the screen.
  /// Defaults to [TalkerScreenTheme] with default values.
  final TalkerScreenTheme theme;

  @override
  State<HttpLogCard> createState() => _HttpLogCardState();
}

class _HttpLogCardState extends State<HttpLogCard> {
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
  }

  @override
  void didUpdateWidget(covariant HttpLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _expanded = widget.expanded;
  }

  AdvancedDioLog? get _advancedLog {
    if (widget.data is AdvancedDioLog) {
      return widget.data as AdvancedDioLog;
    }
    return null;
  }

  HttpLogData? get _httpLogData => _advancedLog?.httpLogData;

  bool get _isRequest => _advancedLog?.type == AdvancedDioLogType.request;
  bool get _isError => _advancedLog?.type == AdvancedDioLogType.error;

  /// Effective display-limit registry.
  ///
  /// Sourced from the [AdvancedDioLoggerSettings] that was baked into the log
  /// at intercept time — this is the single source of truth for the user's
  /// per-content-type display limits.  Falls back to [DisplayLimitRegistry.defaults]
  /// only for non-advanced (plain TalkerData) log entries.
  DisplayLimitRegistry get _effectiveRegistry =>
      _advancedLog?.settings.displayLimitRegistry ??
      DisplayLimitRegistry.defaults;

  Color get _statusColor => StatusColorUtil.getLogTypeColor(
    isRequest: _isRequest,
    isError: _isError,
    statusCode: _httpLogData?.statusCode,
    theme: widget.theme,
  );

  @override
  Widget build(BuildContext context) {
    final httpData = _httpLogData;
    final bgColor = widget.theme.cardColor;

    return Padding(
      padding: widget.margin ?? const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: _statusColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              _buildHeader(),
              const SizedBox(height: 8),
              // URL
              Text(
                httpData?.formattedUrl ?? widget.data.message ?? '',
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(color: _statusColor, fontSize: 12),
              ),
              // Expanded content
              if (_expanded) ...[
                const SizedBox(height: 12),
                _buildExpandedContent(),
              ],
              // Action buttons
              const SizedBox(height: 8),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final httpData = _httpLogData;

    return Row(
      children: [
        // Method badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            httpData?.method ??
                (_isRequest ? 'REQUEST' : (_isError ? 'ERROR' : 'RESPONSE')),
            style: TextStyle(
              color: _statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Status code (for response/error)
        if (httpData?.statusCode != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${httpData!.statusCode}',
              style: TextStyle(
                color: _statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Response time
        if (httpData?.responseTime != null) ...[
          Icon(Icons.timer_outlined, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            '${httpData!.responseTime}ms',
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
          const SizedBox(width: 8),
        ],
        // Response size
        if (httpData?.approximateResponseSize != null &&
            httpData!.approximateResponseSize > 0) ...[
          Icon(Icons.data_usage, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            SizeCalculator.formatBytes(httpData.approximateResponseSize),
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
          const SizedBox(width: 8),
        ],
        // Content type badge
        if (httpData?.contentType != null &&
            httpData!.contentType != HttpContentType.unknown) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              httpData.contentType.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const Spacer(),
        // Timestamp
        Text(
          _formatTime(httpData?.timestamp ?? DateTime.now()),
          style: TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    final httpData = _httpLogData;
    if (httpData == null) {
      return Text(
        widget.data.generateTextMessage(),
        style: TextStyle(color: _statusColor, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show image preview if it's an image response
        if (httpData.isImage && httpData.imageData != null)
          _buildImagePreview(httpData),

        // Show error message if it's an error
        if (_isError && httpData.error != null)
          _buildErrorMessage(httpData.error!),

        // Show response body if available (for non-image responses)
        if (!_isRequest && !httpData.isImage && httpData.responseBody != null)
          _buildResponseBodyPreview(httpData),
      ],
    );
  }

  Widget _buildResponseBodyPreview(HttpLogData httpData) {
    final responseBody = httpData.responseBody;
    if (responseBody == null) return const SizedBox.shrink();

    final displayLimit = _effectiveRegistry.get(httpData.contentType);

    String displayText;
    if (responseBody is Map || responseBody is List) {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        displayText = encoder.convert(responseBody);
      } catch (_) {
        displayText = responseBody.toString();
      }
    } else {
      displayText = responseBody.toString();
    }

    // Check maxBytes first — if over limit, don't show preview at all
    final byteLength = displayText.length;
    if (byteLength > displayLimit.maxBytes) {
      return _buildTooLargeForPreview(byteLength, displayLimit.maxBytes);
    }

    // Calculate lines and check if we need to truncate by maxLines
    final lines = displayText.split('\n');
    final maxLines = displayLimit.maxLines;
    final shouldTruncate = lines.length > maxLines;
    final displayLines = shouldTruncate ? lines.take(maxLines).toList() : lines;
    final truncatedText = displayLines.join('\n');

    // Line number gutter width: enough digits for the last line number
    final lastLineNo = displayLines.length;
    final gutterWidth = lastLineNo.toString().length;

    final codeColor = _getResponseTextColor(httpData.contentType);
    const fontSize = 11.0;
    const fontFamily = 'monospace';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Response',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (shouldTruncate)
                Text(
                  '${lines.length - maxLines} more lines...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Line-numbered body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gutter: right-aligned line numbers
              SelectableText(
                List.generate(
                  displayLines.length,
                  (i) => (i + 1).toString().padLeft(gutterWidth),
                ).join('\n'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  height: 1.4,
                ),
              ),
              const SizedBox(width: 8),
              // Vertical separator
              Container(
                width: 1,
                color: Colors.grey[700],
                margin: const EdgeInsets.only(right: 8),
              ),
              // Code
              Expanded(
                child: SelectableText(
                  truncatedText,
                  style: TextStyle(
                    color: codeColor,
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (shouldTruncate)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tap "Detail" to view full response',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTooLargeForPreview(int byteLength, int maxBytes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Response too large to preview (${SizeCalculator.formatBytes(byteLength)} > ${SizeCalculator.formatBytes(maxBytes)}). Tap "Detail" to view.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getResponseTextColor(HttpContentType contentType) {
    switch (contentType) {
      case HttpContentType.json:
        return Colors.green[300]!;
      case HttpContentType.html:
        return Colors.orange[300]!;
      case HttpContentType.xml:
        return Colors.blue[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  Widget _buildImagePreview(HttpLogData httpData) {
    final canShowInline =
        httpData.imageData!.length <=
        _effectiveRegistry.get(httpData.contentType).maxBytes;

    if (canShowInline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ImagePreview(
          imageData: httpData.imageData!,
          maxHeight: 150,
          showSaveButton: false,
          onTap: () => _openDetailScreen(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ImagePlaceholder(
        size: httpData.imageData!.length,
        onTap: () => _openDetailScreen(),
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Copy cURL button
        _buildActionButton(
          icon: Icons.terminal,
          label: 'cURL',
          onTap: _copyCurl,
        ),
        const SizedBox(width: 8),
        // Detail button
        _buildActionButton(
          icon: Icons.open_in_new,
          label: 'Detail',
          onTap: _openDetailScreen,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap() {
    if (widget.onTap != null) {
      widget.onTap?.call();
      return;
    }
    setState(() => _expanded = !_expanded);
  }

  void _copyCurl() {
    String? curl;

    if (_advancedLog != null) {
      curl = _advancedLog!.curlCommandSafe;
    } else if (_httpLogData?.requestOptions != null) {
      curl = CurlGenerator.generateSafe(_httpLogData!.requestOptions!);
    }

    if (curl != null) {
      Clipboard.setData(ClipboardData(text: curl));
      _showSnackBar('cURL copied (auth hidden)');
    }
  }

  void _openDetailScreen() {
    final httpData = _httpLogData;
    if (httpData == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => TalkerThemeProvider(
              theme: widget.theme,
              child: HttpDetailScreen(
                httpLogData: httpData,
                advancedLog: _advancedLog,
              ),
            ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

/// Builder function type for HTTP log cards
typedef HttpLogCardBuilder =
    Widget Function(BuildContext context, TalkerData data);

/// Returns true if the TalkerData is from the advanced dio logger
bool isAdvancedHttpLog(TalkerData data) {
  return data is AdvancedDioLog;
}

/// Default builder for HTTP log cards that uses HttpLogCard for all logs.
///
/// Display limits are automatically sourced from the [AdvancedDioLoggerSettings]
/// baked into each [AdvancedDioLog] at intercept time — no need to pass them
/// separately here.
Widget buildHttpLogCard(
  BuildContext context,
  TalkerData data, {
  bool expanded = true,
  TalkerScreenTheme theme = const TalkerScreenTheme(),
  VoidCallback? onCopyTap,
}) {
  return HttpLogCard(
    data: data,
    expanded: expanded,
    theme: theme,
    onCopyTap: onCopyTap,
  );
}
