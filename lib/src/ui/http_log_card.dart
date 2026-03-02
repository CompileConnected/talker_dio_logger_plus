import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/ui/image_preview.dart';
import 'package:talker_dio_logger_plus/src/utils/clipboard_util.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';
import 'package:talker_dio_logger_plus/src/utils/status_color.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../talker_dio_logger_plus.dart';

const _jsonEncoder = JsonEncoder.withIndent('  ');

/// A card that displays a single HTTP log entry (request, response, or error).
///
/// Renders an expandable card showing method, URL, status, timing, and a
/// truncated preview of the response body. Tap "Detail" to navigate to the
/// full [HttpDetailScreen].
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

  /// Theme for the Talker screen. Defaults to [TalkerScreenTheme].
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

  /// The underlying advanced log, or `null` for plain [TalkerData].
  AdvancedDioLog? get _advancedLog =>
      widget.data is AdvancedDioLog ? widget.data as AdvancedDioLog : null;

  HttpLogData? get _httpLogData => _advancedLog?.httpLogData;

  bool get _isRequest => _advancedLog?.type == AdvancedDioLogType.request;

  bool get _isError => _advancedLog?.type == AdvancedDioLogType.error;

  bool get _enableCurl => _advancedLog?.settings.enableCurlGeneration ?? false;

  /// Display-limit registry from settings (falls back to defaults).
  DisplayLimitRegistry get _displayLimits =>
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

    return Padding(
      padding: widget.margin ?? const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.theme.cardColor,
            border: Border.all(color: _statusColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              // URL
              Text(
                httpData?.formattedUrl ?? widget.data.message ?? '',
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(color: _statusColor, fontSize: 12),
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                _buildExpandedContent(),
              ],
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
        // Method badge (e.g. GET, POST)
        _StatusBadge(
          label:
              httpData?.method ??
              (_isRequest ? 'REQUEST' : (_isError ? 'ERROR' : 'RESPONSE')),
          color: _statusColor,
        ),
        const SizedBox(width: 8),

        // Status code badge (e.g. 200, 404)
        if (httpData?.statusCode != null) ...[
          _StatusBadge(label: '${httpData!.statusCode}', color: _statusColor),
          const SizedBox(width: 8),
        ],

        // Response time
        if (httpData?.responseTime != null) ...[
          _MetaLabel(
            icon: Icons.timer_outlined,
            text: '${httpData!.responseTime}ms',
          ),
          const SizedBox(width: 8),
        ],

        // Response size
        if (httpData != null && httpData.approximateResponseSize > 0) ...[
          _MetaLabel(
            icon: Icons.data_usage,
            text: SizeCalculator.formatBytes(httpData.approximateResponseSize),
          ),
          const SizedBox(width: 8),
        ],

        // Content type tag (JSON, HTML, etc.)
        if (httpData != null &&
            httpData.contentType != HttpBodyType.unknown) ...[
          _ContentTypeBadge(contentType: httpData.contentType),
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
        if (httpData.isImage && httpData.imageData != null)
          _buildImagePreview(httpData),

        if (_isError && httpData.error != null)
          _buildErrorMessage(httpData.error!),

        if (!_isRequest && !httpData.isImage && httpData.responseBody != null)
          _buildResponseBodyPreview(httpData),
      ],
    );
  }

  Widget _buildResponseBodyPreview(HttpLogData httpData) {
    final responseBody = httpData.responseBody;
    if (responseBody == null) return const SizedBox.shrink();

    // Respect the enablePreview flag — when false, skip the UI preview entirely.
    final displayLimit = _displayLimits.get(httpData.contentType);
    if (!displayLimit.enablePreview) {
      return _buildPreviewDisabledNotice();
    }

    // Step 1: Convert body to displayable text.
    final displayText = _bodyToString(responseBody);

    // Step 2: Check size limit — skip preview if too large.
    if (displayText.length > displayLimit.maxBytes) {
      return _buildTooLargeNotice(displayText.length, displayLimit.maxBytes);
    }

    // Step 3: Truncate by line count if needed.
    final allLines = displayText.split('\n');
    final maxLines = displayLimit.maxLines;
    final isTruncated = allLines.length > maxLines;
    final visibleLines =
        isTruncated ? allLines.take(maxLines).toList() : allLines;

    // Step 4: Render the code block with line numbers.
    return _CodePreview(
      lines: visibleLines,
      codeColor: _getResponseTextColor(httpData.contentType),
      isTruncated: isTruncated,
      hiddenLineCount: isTruncated ? allLines.length - maxLines : 0,
    );
  }

  /// Converts a response body (Map, List, or other) to a pretty-printed string.
  static String _bodyToString(dynamic body) {
    if (body is Map || body is List) {
      try {
        return _jsonEncoder.convert(body);
      } catch (_) {
        return body.toString();
      }
    }
    return body.toString();
  }

  Widget _buildTooLargeNotice(int actualBytes, int maxBytes) {
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
              'Response too large to preview '
              '(${SizeCalculator.formatBytes(actualBytes)} > '
              '${SizeCalculator.formatBytes(maxBytes)}). '
              'Tap "Detail" to view.',
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

  Color _getResponseTextColor(HttpBodyType contentType) {
    return switch (contentType) {
      HttpBodyType.json => Colors.green[300]!,
      HttpBodyType.html => Colors.orange[300]!,
      HttpBodyType.xml => Colors.blue[300]!,
      _ => Colors.grey[300]!,
    };
  }

  Widget _buildPreviewDisabledNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 14,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Preview disabled for this content type. '
              'Tap "Detail" to view.',
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

  Widget _buildImagePreview(HttpLogData httpData) {
    final imageBytes = httpData.imageData!;
    final limit = _displayLimits.get(httpData.contentType);

    // Respect the enablePreview flag.
    if (!limit.enablePreview) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildPreviewDisabledNotice(),
      );
    }

    if (imageBytes.length <= limit.maxBytes) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ImagePreview(
          imageData: imageBytes,
          maxHeight: 150,
          showSaveButton: false,
          onTap: _openDetailScreen,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ImagePlaceholder(
        size: imageBytes.length,
        onTap: _openDetailScreen,
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
        if (_enableCurl)
          _ActionChip(icon: Icons.terminal, label: 'cURL', onTap: _copyCurl),

        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.open_in_new,
          label: 'Detail',
          onTap: _openDetailScreen,
        ),
      ],
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
      ClipboardUtil.copy(
        curl,
        context: context,
        snackBarMessage: 'cURL copied (auth hidden)',
      );
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

/// A coloured pill showing a label (method name or status code).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Icon + text pair for metadata (response time, size).
class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }
}

/// Small grey tag showing the content type (JSON, HTML, etc.).
class _ContentTypeBadge extends StatelessWidget {
  const _ContentTypeBadge({required this.contentType});

  final HttpBodyType contentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        contentType.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A small tappable chip with an icon and label (e.g. "cURL", "Detail").
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}

/// A code block with line numbers and an optional "truncated" hint.
///
/// Extracted so that `_buildResponseBodyPreview` only has to prepare the data
/// and this widget handles all the rendering boilerplate.
class _CodePreview extends StatelessWidget {
  const _CodePreview({
    required this.lines,
    required this.codeColor,
    this.isTruncated = false,
    this.hiddenLineCount = 0,
  });

  final List<String> lines;
  final Color codeColor;
  final bool isTruncated;
  final int hiddenLineCount;

  @override
  Widget build(BuildContext context) {
    // Width of the gutter (enough digits for the last line number).
    final gutterWidth = lines.length.toString().length;

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
          // Title row
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
              if (isTruncated)
                Text(
                  '$hiddenLineCount more lines...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Line-numbered body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers
              SelectableText(
                List.generate(
                  lines.length,
                  (i) => (i + 1).toString().padLeft(gutterWidth),
                ).join('\n'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                  fontSize: 11,
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
                  lines.join('\n'),
                  style: TextStyle(
                    color: codeColor,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          // "Tap Detail" hint
          if (isTruncated)
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
}

/// Returns `true` if [data] is from [AdvancedDioLogger].
bool isAdvancedHttpLog(TalkerData data) {
  return data is AdvancedDioLog;
}
