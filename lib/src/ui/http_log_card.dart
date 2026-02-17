import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/ui/http_detail_screen.dart';
import 'package:talker_dio_logger_plus/src/ui/image_preview.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';

/// Custom HTTP log card widget with advanced features
class HttpLogCard extends StatefulWidget {
  const HttpLogCard({
    super.key,
    required this.data,
    this.onCopyTap,
    this.onTap,
    this.expanded = true,
    this.margin,
    this.backgroundColor,
    this.maxJsonLines = 15,
    this.imagePreviewThreshold = 500 * 1024,
  });

  final TalkerData data;
  final VoidCallback? onCopyTap;
  final VoidCallback? onTap;
  final bool expanded;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final int maxJsonLines;
  final int imagePreviewThreshold;

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

  HttpLogData? get _httpLogData {
    if (widget.data is AdvancedDioRequestLog) {
      return (widget.data as AdvancedDioRequestLog).httpLogData;
    }
    if (widget.data is AdvancedDioResponseLog) {
      return (widget.data as AdvancedDioResponseLog).httpLogData;
    }
    if (widget.data is AdvancedDioErrorLog) {
      return (widget.data as AdvancedDioErrorLog).httpLogData;
    }
    return null;
  }

  bool get _isRequest => widget.data is AdvancedDioRequestLog;
  bool get _isError => widget.data is AdvancedDioErrorLog;

  Color get _statusColor {
    if (_isRequest) return const Color(0xFFF602C1);
    if (_isError) return Colors.red;

    final statusCode = _httpLogData?.statusCode;
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return const Color(0xFF26FF3C);
    if (statusCode >= 300 && statusCode < 400) return Colors.orange;
    if (statusCode >= 400) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final httpData = _httpLogData;
    final bgColor =
        widget.backgroundColor ?? const Color.fromARGB(255, 49, 49, 49);

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
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 12,
                ),
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
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
            ),
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
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    final httpData = _httpLogData;
    if (httpData == null) {
      return Text(
        widget.data.generateTextMessage(),
        style: TextStyle(
          color: _statusColor,
          fontSize: 12,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show image preview if it's an image response
        if (httpData.isImage && httpData.imageData != null)
          _buildImagePreview(httpData),

        // Show truncation warning if data is truncated
        if (httpData.isTruncated) _buildTruncationWarning(httpData),

        // Show error message if it's an error
        if (_isError && httpData.error != null)
          _buildErrorMessage(httpData.error!),

        // Size info
        if (httpData.contentLength != null)
          _buildSizeInfo(httpData.contentLength!),
      ],
    );
  }

  Widget _buildImagePreview(HttpLogData httpData) {
    final canShowInline =
        httpData.imageData!.length <= widget.imagePreviewThreshold;

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

  Widget _buildTruncationWarning(HttpLogData httpData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data truncated. Tap to view full content.',
              style: TextStyle(color: Colors.orange[300], fontSize: 11),
            ),
          ),
        ],
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

  Widget _buildSizeInfo(int size) {
    return Row(
      children: [
        Icon(Icons.data_usage, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          SizeCalculator.formatBytes(size),
          style: TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
      ],
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

    if (widget.data is AdvancedDioRequestLog) {
      curl = (widget.data as AdvancedDioRequestLog).curlCommandSafe;
    } else if (widget.data is AdvancedDioErrorLog) {
      curl = (widget.data as AdvancedDioErrorLog).curlCommandSafe;
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
        builder: (context) => HttpDetailScreen(
          httpLogData: httpData,
          requestLog: widget.data is AdvancedDioRequestLog
              ? widget.data as AdvancedDioRequestLog
              : null,
          responseLog: widget.data is AdvancedDioResponseLog
              ? widget.data as AdvancedDioResponseLog
              : null,
          errorLog: widget.data is AdvancedDioErrorLog
              ? widget.data as AdvancedDioErrorLog
              : null,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

/// Builder function type for HTTP log cards
typedef HttpLogCardBuilder = Widget Function(
  BuildContext context,
  TalkerData data,
);

/// Returns true if the TalkerData is from the advanced dio logger
bool isAdvancedHttpLog(TalkerData data) {
  return data is AdvancedDioRequestLog ||
      data is AdvancedDioResponseLog ||
      data is AdvancedDioErrorLog;
}

/// Default builder for HTTP log cards that uses HttpLogCard for advanced logs
Widget buildHttpLogCard(
  BuildContext context,
  TalkerData data, {
  bool expanded = true,
  Color? backgroundColor,
  VoidCallback? onCopyTap,
}) {
  if (isAdvancedHttpLog(data)) {
    return HttpLogCard(
      data: data,
      expanded: expanded,
      backgroundColor: backgroundColor,
      onCopyTap: onCopyTap,
    );
  }

  // Fallback to default card for non-advanced logs
  // You can customize this or return null to use the default TalkerDataCard
  return HttpLogCard(
    data: data,
    expanded: expanded,
    backgroundColor: backgroundColor,
    onCopyTap: onCopyTap,
  );
}
