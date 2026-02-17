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

/// Detailed view screen for HTTP logs
class HttpDetailScreen extends StatefulWidget {
  const HttpDetailScreen({
    super.key,
    required this.httpLogData,
    this.requestLog,
    this.responseLog,
    this.errorLog,
    this.backgroundColor,
    this.primaryColor,
  });

  final HttpLogData httpLogData;
  final AdvancedDioRequestLog? requestLog;
  final AdvancedDioResponseLog? responseLog;
  final AdvancedDioErrorLog? errorLog;
  final Color? backgroundColor;
  final Color? primaryColor;

  @override
  State<HttpDetailScreen> createState() => _HttpDetailScreenState();
}

class _HttpDetailScreenState extends State<HttpDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFullCurl = false;

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final primaryColor = widget.primaryColor ?? _getStatusColor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.httpLogData.method} ${widget.httpLogData.path}',
              style: const TextStyle(fontSize: 14),
            ),
            if (widget.httpLogData.statusCode != null)
              Text(
                'Status: ${widget.httpLogData.statusCode}',
                style: TextStyle(
                  fontSize: 12,
                  color: primaryColor,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
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

  Color _getStatusColor() {
    final statusCode = widget.httpLogData.statusCode;
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 300 && statusCode < 400) return Colors.orange;
    if (statusCode >= 400 && statusCode < 500) return Colors.red;
    if (statusCode >= 500) return Colors.red[900]!;
    return Colors.grey;
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

    final curl = safe
        ? CurlGenerator.generateSafe(options)
        : CurlGenerator.generateFull(options);

    Clipboard.setData(ClipboardData(text: curl));
    _showSnackBar('cURL command copied to clipboard');
  }

  Future<void> _downloadAsZip() async {
    final path = await FileSaver.saveHttpLogToZip(widget.httpLogData);
    if (path != null) {
      _showSnackBar('Saved to $path');
    } else {
      _showSnackBar('Failed to save file');
    }
  }

  Future<void> _share() async {
    await FileSaver.saveAndShareHttpLog(widget.httpLogData);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                  'Status', '${data.statusCode} ${data.statusMessage ?? ""}'),
            if (data.responseTime != null)
              _buildInfoRow('Response Time', '${data.responseTime}ms'),
            _buildInfoRow('Timestamp', data.timestamp.toIso8601String()),
            _buildInfoRow('Content Type', data.contentType.name),
            if (data.contentLength != null)
              _buildInfoRow('Content Length',
                  SizeCalculator.formatBytes(data.contentLength!)),
          ]),
          const SizedBox(height: 16),
          if (data.error != null)
            _buildInfoCard('Error', [
              _buildInfoRow('Message', data.error!),
            ]),
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
    final data = widget.httpLogData;
    final hasBody = data.requestBody != null || data.fullRequestBody != null;

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
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Empty body request',
                style: TextStyle(
                  color: Colors.grey[500],
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

    final safeCurl = CurlGenerator.generateSafe(options);
    final fullCurl = CurlGenerator.generateFull(options);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'cURL Command',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
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
                icon: const Icon(Icons.copy, color: Colors.white, size: 20),
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
            _buildSectionHeader('Headers'),
            const SizedBox(height: 8),
            _buildResponseHeadersView(data.responseHeaders!),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader('Body'),
          const SizedBox(height: 8),
          _buildResponseBodyView(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildHeadersView(Map<String, dynamic> headers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: headers.entries.map((entry) {
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: headers.entries.map((entry) {
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
    if (body == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No body',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (body is Map || body is List) {
      return SizedBox(
        height: 400,
        child: SearchableJsonViewer(
          data: body,
          initiallyExpanded: !isTruncated,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
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

    // Handle image response
    if (data.isImage && data.imageData != null) {
      return ImagePreview(
        imageData: data.imageData!,
        maxHeight: 300,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullScreenImageViewer(
                imageData: data.imageData!,
                title: 'Response Image',
                mimeType: data.responseHeaders?['content-type']?.first,
              ),
            ),
          );
        },
        onSave: () async {
          final ext = data.responseHeaders?['content-type']?.first ?? '.png';
          final filename = 'image_${DateTime.now().millisecondsSinceEpoch}$ext';
          final path = await FileSaver.saveToFile(
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
      final htmlContent = data.fullResponseBody?.toString() ??
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
                  builder: (context) => FullScreenHtmlPreview(
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
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No response body',
          style: TextStyle(color: Colors.grey),
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
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
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
        color: Colors.grey[900],
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
