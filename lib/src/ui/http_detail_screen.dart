import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/ui/image_preview.dart';
import 'package:talker_dio_logger_plus/src/ui/searchable_json_viewer.dart';
import 'package:talker_dio_logger_plus/src/ui/web_view_preview.dart';
import 'package:talker_dio_logger_plus/src/utils/file_saver.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';

import '../../talker_dio_logger_plus.dart';
import '../utils/status_color.dart';

/// Detailed view screen for HTTP logs
class HttpDetailScreen extends StatefulWidget {
  const HttpDetailScreen({
    super.key,
    required this.httpLogData,
    this.advancedLog,
    this.fileSaver,
  });

  final HttpLogData httpLogData;
  final AdvancedDioLog? advancedLog;

  /// Custom file saver implementation.
  /// If not provided, uses [DefaultFileSaver].
  final FileSaverInterface? fileSaver;

  @override
  State<HttpDetailScreen> createState() => _HttpDetailScreenState();
}

class _HttpDetailScreenState extends State<HttpDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFullCurl = false;

  // Collapsible section states for Response tab
  bool _responseHeadersExpanded = true;
  bool _responseBodyExpanded = true;

  /// Get the file saver instance, defaulting to DefaultFileSaver
  FileSaverInterface get _fileSaver =>
      widget.fileSaver ?? const DefaultFileSaver();

  /// Get the jsonSoftWrapTextValueAtWidth setting from the advanced log
  double? get jsonSoftWrapTextValueAtWidth =>
      widget.advancedLog?.settings.jsonSoftWrapTextValueAtWidth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TalkerThemeProvider.of(context);

    final bgColor = theme.backgroundColor;
    final textColor = theme.textColor;
    final primaryColor = StatusColorUtil.getStatusColor(
      widget.httpLogData.statusCode,
      theme,
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.httpLogData.method} ${widget.httpLogData.path}',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
            if (widget.httpLogData.statusCode != null)
              Text(
                'Status: ${widget.httpLogData.statusCode}',
                style: TextStyle(fontSize: 12, color: primaryColor),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            onSelected: _handleMenuAction,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'copy_curl',
                    child: Row(
                      children: [
                        Icon(Icons.terminal, size: 20),
                        SizedBox(width: 8),
                        Text('Copy cURL'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_curl_safe',
                    child: Row(
                      children: [
                        Icon(Icons.security, size: 20),
                        SizedBox(width: 8),
                        Text('Copy cURL (hidden auth)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Download as ZIP'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: textColor.withValues(alpha: 0.7),
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Request'),
            Tab(text: 'Response'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildRequestTab(),
          _buildResponseTab(),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'copy_curl':
        _copyCurl(safe: false);
        break;
      case 'copy_curl_safe':
        _copyCurl(safe: true);
        break;
      case 'download':
        _downloadAsZip();
        break;
      case 'share':
        _share();
        break;
    }
  }

  void _copyCurl({required bool safe}) {
    final options = widget.httpLogData.requestOptions;
    if (options == null) {
      _showSnackBar('Request options not available');
      return;
    }

    final curl =
        safe
            ? CurlGenerator.generateSafe(options)
            : CurlGenerator.generateFull(options);

    Clipboard.setData(ClipboardData(text: curl));
    _showSnackBar('cURL command copied to clipboard');
  }

  Future<void> _downloadAsZip() async {
    final path = await _fileSaver.saveHttpLogToZip(widget.httpLogData);
    if (path != null) {
      _showSnackBar('Saved to $path');
    } else {
      _showSnackBar('Failed to save file');
    }
  }

  Future<void> _share() async {
    await _fileSaver.saveAndShareHttpLog(widget.httpLogData);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildOverviewTab() {
    final data = widget.httpLogData;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard('General', [
            _buildInfoRow('Method', data.method),
            _buildInfoRow('URL', data.formattedUrl),
            _buildInfoRow('Path', data.path),
            if (data.statusCode != null)
              _buildInfoRow(
                'Status',
                '${data.statusCode} ${data.statusMessage ?? ""}',
              ),
            if (data.responseTime != null)
              _buildInfoRow('Response Time', '${data.responseTime}ms'),
            _buildInfoRow('Timestamp', data.timestamp.toIso8601String()),
            _buildInfoRow('Content Type', data.contentType.name),
            if (data.contentLength != null)
              _buildInfoRow(
                'Content Length',
                SizeCalculator.formatBytes(data.contentLength!),
              ),
            if (data.approximateResponseSize > 0)
              _buildInfoRow(
                'Response Size',
                SizeCalculator.formatBytes(data.approximateResponseSize),
              ),
          ]),
          const SizedBox(height: 16),
          if (data.error != null)
            _buildInfoCard('Error', [_buildInfoRow('Message', data.error!)]),
          if (data.requestQueryParams != null &&
              data.requestQueryParams!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoCard('Query Parameters', [
              for (final entry in data.requestQueryParams!.entries)
                _buildInfoRow(entry.key, entry.value.toString()),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    final theme = TalkerThemeProvider.of(context);

    final data = widget.httpLogData;
    final hasBody = data.requestBody != null || data.fullRequestBody != null;
    final cardColor = theme.cardColor;
    final textColor = theme.textColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurlSection(),
          const SizedBox(height: 16),
          if (data.requestHeaders != null &&
              data.requestHeaders!.isNotEmpty) ...[
            _buildSectionHeader('Headers'),
            const SizedBox(height: 8),
            _buildHeadersView(data.requestHeaders!),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader('Body'),
          const SizedBox(height: 8),
          if (hasBody)
            _buildBodyView(
              data.fullRequestBody ?? data.requestBody,
              isTruncated: data.isRequestTruncated,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Empty body request',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurlSection() {
    final options = widget.httpLogData.requestOptions;
    if (options == null) {
      return const SizedBox.shrink();
    }
    final theme = TalkerThemeProvider.of(context);

    final safeCurl = CurlGenerator.generateSafe(options);
    final fullCurl = CurlGenerator.generateFull(options);
    final cardColor = theme.cardColor;
    final textColor = theme.textColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'cURL Command',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const Spacer(),
            Switch(
              value: _showFullCurl,
              onChanged: (value) {
                setState(() {
                  _showFullCurl = value;
                });
              },
            ),
            Text(
              _showFullCurl ? 'Show Full' : 'Hide Auth',
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  _showFullCurl ? fullCurl : safeCurl,
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: textColor, size: 20),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _showFullCurl ? fullCurl : safeCurl),
                  );
                  _showSnackBar('cURL copied to clipboard');
                },
              ),
            ],
          ),
        ),
        if (!_showFullCurl) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Authorization headers are hidden. Toggle "Show Full" to see all values.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResponseTab() {
    final data = widget.httpLogData;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.responseHeaders != null &&
              data.responseHeaders!.isNotEmpty) ...[
            _buildCollapsibleSection(
              title: 'Headers',
              isExpanded: _responseHeadersExpanded,
              onToggle: () {
                setState(() {
                  _responseHeadersExpanded = !_responseHeadersExpanded;
                });
              },
              child: _buildResponseHeadersView(data.responseHeaders!),
            ),
            const SizedBox(height: 16),
          ],
          _buildCollapsibleSection(
            title: 'Body',
            isExpanded: _responseBodyExpanded,
            onToggle: () {
              setState(() {
                _responseBodyExpanded = !_responseBodyExpanded;
              });
            },
            child: _buildResponseBodyView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final theme = TalkerThemeProvider.of(context);

    final textColor = theme.textColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right, color: textColor, size: 20),
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: child,
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    final theme = TalkerThemeProvider.of(context);

    final cardColor = theme.cardColor;
    final textColor = theme.textColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = TalkerThemeProvider.of(context);

    final textColor = theme.textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = TalkerThemeProvider.of(context);

    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: theme.textColor,
      ),
    );
  }

  Widget _buildHeadersView(Map<String, dynamic> headers) {
    final theme = TalkerThemeProvider.of(context);

    final cardColor = theme.cardColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            headers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: TextStyle(
                          color: Colors.purple[300],
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      TextSpan(
                        text: entry.value.toString(),
                        style: TextStyle(
                          color: Colors.green[300],
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildResponseHeadersView(Map<String, List<String>> headers) {
    final theme = TalkerThemeProvider.of(context);

    final cardColor = theme.cardColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            headers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: TextStyle(
                          color: Colors.purple[300],
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      TextSpan(
                        text: entry.value.join(', '),
                        style: TextStyle(
                          color: Colors.green[300],
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildBodyView(dynamic body, {bool isTruncated = false}) {
    final theme = TalkerThemeProvider.of(context);

    final cardColor = theme.cardColor;
    final textColor = theme.textColor;

    if (body == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No body',
          style: TextStyle(color: textColor.withValues(alpha: 0.5)),
        ),
      );
    }

    if (body is Map || body is List) {
      return SizedBox(
        height: 400,
        child: SearchableJsonViewer(
          data: body,
          initiallyExpanded: !isTruncated,
          jsonSoftWrapTextValueAtWidth: jsonSoftWrapTextValueAtWidth,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        body.toString(),
        style: TextStyle(
          color: Colors.green[300],
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildResponseBodyView() {
    final data = widget.httpLogData;
    final theme = TalkerThemeProvider.of(context);

    // Handle image response
    if (data.isImage && data.imageData != null) {
      return ImagePreview(
        imageData: data.imageData!,
        maxHeight: 300,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => FullScreenImageViewer(
                    imageData: data.imageData!,
                    title: 'Response Image',
                    mimeType: data.responseHeaders?['content-type']?.first,
                    fileSaver: widget.fileSaver,
                  ),
            ),
          );
        },
        onSave: () async {
          final ext = data.responseHeaders?['content-type']?.first ?? '.png';
          final filename = 'image_${DateTime.now().millisecondsSinceEpoch}$ext';
          final path = await _fileSaver.saveToFile(
            filename: filename,
            data: data.imageData!,
          );
          if (path != null) {
            _showSnackBar('Saved to $path');
          }
        },
      );
    }

    // Handle HTML response
    if (data.isHtml) {
      final htmlContent =
          data.fullResponseBody?.toString() ??
          data.responseBody?.toString() ??
          '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebViewPreview(
            htmlContent: htmlContent,
            maxHeight: 200,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => FullScreenHtmlPreview(
                        htmlContent: htmlContent,
                        title: 'HTML Response',
                      ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: htmlContent));
              _showSnackBar('HTML copied to clipboard');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy HTML'),
          ),
        ],
      );
    }

    // Handle JSON response
    final responseBody = data.fullResponseBody ?? data.responseBody;
    if (responseBody == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No response body',
          style: TextStyle(color: theme.textColor.withValues(alpha: 0.5)),
        ),
      );
    }

    if (responseBody is Map || responseBody is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.isResponseTruncated)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Response truncated. Size: ${SizeCalculator.formatBytes(SizeCalculator.calculateSize(data.fullResponseBody))}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 400,
            child: SearchableJsonViewer(
              data: responseBody,
              initiallyExpanded: !data.isResponseTruncated,
              jsonSoftWrapTextValueAtWidth: jsonSoftWrapTextValueAtWidth,
            ),
          ),
        ],
      );
    }

    // Handle text response
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        responseBody.toString(),
        style: TextStyle(
          color: Colors.green[300],
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}
