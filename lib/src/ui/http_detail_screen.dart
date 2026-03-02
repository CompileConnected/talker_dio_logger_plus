import 'package:flutter/material.dart';
import 'package:talker_dio_logger_plus/src/advanced_dio_logs.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/ui/image_preview.dart';
import 'package:talker_dio_logger_plus/src/ui/searchable_json_viewer.dart';
import 'package:talker_dio_logger_plus/src/ui/web_view_preview.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';
import 'package:talker_dio_logger_plus/src/utils/snackbar_util.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../talker_dio_logger_plus.dart';
import '../utils/clipboard_util.dart';
import '../utils/status_color.dart';

/// Shows the full details of an HTTP log entry
class HttpDetailScreen extends StatefulWidget {
  const HttpDetailScreen({
    super.key,
    required this.httpLogData,
    this.advancedLog,
  });

  final HttpLogData httpLogData;
  final AdvancedDioLog? advancedLog;

  @override
  State<HttpDetailScreen> createState() => _HttpDetailScreenState();
}

class _HttpDetailScreenState extends State<HttpDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFullCurl = false;

  // Collapsible section states for the Response tab.
  bool _responseHeadersExpanded = true;
  bool _responseBodyExpanded = true;

  HttpLogData get _data => widget.httpLogData;
  FileSaverInterface? get _fileSaver => widget.advancedLog?.settings.fileSaver;
  double? get _jsonWrapWidth =>
      widget.advancedLog?.settings.jsonSoftWrapTextValueAtWidth;

  bool get _enableCurl =>
      widget.advancedLog?.settings.enableCurlGeneration ?? false;

  /// Display-limit registry from settings (falls back to defaults).
  DisplayLimitRegistry get _displayLimits =>
      widget.advancedLog?.settings.displayLimitRegistry ??
      DisplayLimitRegistry.defaults;

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
    final primaryColor = StatusColorUtil.getStatusColor(
      _data.statusCode,
      theme,
    );

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_data.method} ${_data.path}',
              style: TextStyle(fontSize: 14, color: theme.textColor),
            ),
            if (_data.statusCode != null)
              Text(
                'Status: ${_data.statusCode}',
                style: TextStyle(fontSize: 12, color: primaryColor),
              ),
          ],
        ),
        actions: [_buildOverflowMenu(theme.textColor)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: theme.textColor.withValues(alpha: 0.7),
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

  Widget _buildOverflowMenu(Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: _handleMenuAction,
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('Download as ZIP'),
                ],
              ),
            ),
            PopupMenuItem(
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
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'download':
        _downloadAsZip();
        break;
      case 'share':
        _share();
        break;
    }
  }

  Future<void> _downloadAsZip() async {
    final fileSaver = _fileSaver;
    if (fileSaver == null) {
      _showFileSaverNotConfigured();
      return;
    }

    final path = await fileSaver.saveHttpLogToZip(_data);
    if (path != null) {
      SnackBarUtil.show(context, 'Saved to $path');
    } else {
      SnackBarUtil.show(context, 'Failed to save file');
    }
  }

  Future<void> _share() async {
    final fileSaver = _fileSaver;
    if (fileSaver == null) {
      _showFileSaverNotConfigured();
      return;
    }
    await fileSaver.saveAndShareHttpLog(_data);
  }

  /// Shows a snackbar when the file saver has not been configured.
  void _showFileSaverNotConfigured() {
    SnackBarUtil.show(
      context,
      'File saver is not configured.\n'
      'Please configure it first on AdvancedDioLoggerSettings.',
    );
  }

  // ===========================================================================
  // Tab 1 — Overview
  // ===========================================================================

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'General',
            rows: [
              _InfoRow(label: 'Method', value: _data.method),
              _InfoRow(label: 'URL', value: _data.formattedUrl),
              _InfoRow(label: 'Path', value: _data.path),
              if (_data.statusCode != null)
                _InfoRow(
                  label: 'Status',
                  value: '${_data.statusCode} ${_data.statusMessage ?? ""}',
                ),
              if (_data.responseTime != null)
                _InfoRow(
                  label: 'Response Time',
                  value: '${_data.responseTime}ms',
                ),
              _InfoRow(
                label: 'Timestamp',
                value: _data.timestamp.toIso8601String(),
              ),
              _InfoRow(label: 'Content Type', value: _data.contentType.name),
              if (_data.contentLength != null)
                _InfoRow(
                  label: 'Content Length',
                  value: SizeCalculator.formatBytes(_data.contentLength!),
                ),
              if (_data.approximateResponseSize > 0)
                _InfoRow(
                  label: 'Response Size',
                  value: SizeCalculator.formatBytes(
                    _data.approximateResponseSize,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_data.error != null)
            _InfoCard(
              title: 'Error',
              rows: [_InfoRow(label: 'Message', value: _data.error!)],
            ),
          if (_data.requestQueryParams != null &&
              _data.requestQueryParams!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Query Parameters',
              rows: [
                for (final entry in _data.requestQueryParams!.entries)
                  _InfoRow(label: entry.key, value: entry.value.toString()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 2 — Request
  // ===========================================================================

  Widget _buildRequestTab() {
    final theme = TalkerThemeProvider.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // cURL command
          if (_enableCurl) ...[
            _buildCurlSection(theme),
            const SizedBox(height: 16),
          ],

          // Request headers
          if (_data.requestHeaders != null &&
              _data.requestHeaders!.isNotEmpty) ...[
            _SectionHeader(title: 'Headers', textColor: theme.textColor),
            const SizedBox(height: 8),
            _HeadersList(
              entries:
                  _data.requestHeaders!.entries
                      .map((e) => MapEntry(e.key, e.value.toString()))
                      .toList(),
              cardColor: theme.cardColor,
            ),
            const SizedBox(height: 16),
          ],

          // Request body
          _SectionHeader(title: 'Body', textColor: theme.textColor),
          const SizedBox(height: 8),
          _data.requestBody != null
              ? _buildBodyView(_data.requestBody)
              : _EmptyState(
                message: 'Empty body request',
                cardColor: theme.cardColor,
                textColor: theme.textColor,
              ),
        ],
      ),
    );
  }

  Widget _buildCurlSection(TalkerScreenTheme theme) {
    final options = _data.requestOptions;
    if (options == null) return const SizedBox.shrink();

    final safeCurl = CurlGenerator.generateSafe(options);
    final fullCurl = CurlGenerator.generateFull(options);
    final displayedCurl = _showFullCurl ? fullCurl : safeCurl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with toggle
        Row(
          children: [
            Text(
              'cURL Command',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const Spacer(),
            Switch(
              value: _showFullCurl,
              onChanged: (v) => setState(() => _showFullCurl = v),
            ),
            Text(
              _showFullCurl ? 'Hide Auth' : 'Show Full',
              style: TextStyle(fontSize: 12, color: theme.textColor),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // cURL text box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  displayedCurl,
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: theme.textColor, size: 20),
                onPressed:
                    () => ClipboardUtil.copy(
                      displayedCurl,
                      context: context,
                      snackBarMessage: 'cURL copied to clipboard',
                    ),
              ),
            ],
          ),
        ),

        // Warning banner when auth is hidden
        if (!_showFullCurl) ...[
          const SizedBox(height: 8),
          const _AuthHiddenBanner(),
        ],
      ],
    );
  }

  // ===========================================================================
  // Tab 3 — Response
  // ===========================================================================

  Widget _buildResponseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Response headers (collapsible)
          if (_data.responseHeaders != null &&
              _data.responseHeaders!.isNotEmpty) ...[
            _buildCollapsibleSection(
              title: 'Headers',
              isExpanded: _responseHeadersExpanded,
              onToggle:
                  () => setState(
                    () => _responseHeadersExpanded = !_responseHeadersExpanded,
                  ),
              child: _HeadersList(
                entries:
                    _data.responseHeaders!.entries
                        .map((e) => MapEntry(e.key, e.value.join(', ')))
                        .toList(),
                cardColor: TalkerThemeProvider.of(context).cardColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Response body (collapsible)
          _buildCollapsibleSection(
            title: 'Body',
            isExpanded: _responseBodyExpanded,
            onToggle:
                () => setState(
                  () => _responseBodyExpanded = !_responseBodyExpanded,
                ),
            child: _buildResponseBodyView(),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseBodyView() {
    final theme = TalkerThemeProvider.of(context);

    // Image
    if (_data.isImage && _data.imageData != null) {
      final imageLimit = _displayLimits.get(HttpBodyType.image);
      if (!imageLimit.enablePreview) {
        return _buildPreviewDisabledNotice(theme);
      }
      return _buildImageResponseBody();
    }

    // HTML
    if (_data.isHtml) {
      final htmlLimit = _displayLimits.get(HttpBodyType.html);
      if (!htmlLimit.enablePreview) {
        return _buildPreviewDisabledNotice(theme);
      }
      return _buildHtmlResponseBody();
    }

    // JSON / text / empty
    final responseBody = _data.responseBody;
    if (responseBody == null) {
      return _EmptyState(
        message: 'No response body',
        cardColor: theme.cardColor,
        textColor: theme.textColor,
      );
    }

    // Check enablePreview for other content types.
    final bodyLimit = _displayLimits.get(_data.contentType);
    if (!bodyLimit.enablePreview) {
      return _buildPreviewDisabledNotice(theme);
    }

    return _buildBodyView(responseBody);
  }

  Widget _buildPreviewDisabledNotice(TalkerScreenTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 16,
            color: theme.textColor.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Preview is disabled for this content type.',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageResponseBody() {
    return ImagePreview(
      imageData: _data.imageData!,
      maxHeight: 300,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => FullScreenImageViewer(
                  imageData: _data.imageData!,
                  title: 'Response Image',
                  mimeType: _data.responseHeaders?['content-type']?.first,
                  fileSaver: _fileSaver,
                ),
          ),
        );
      },
      onSave: () => _saveImage(),
    );
  }

  Future<void> _saveImage() async {
    final fileSaver = _fileSaver;
    if (fileSaver == null) {
      _showFileSaverNotConfigured();
      return;
    }
    final ext = _data.responseHeaders?['content-type']?.first ?? '.png';
    final filename = 'image_${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = await fileSaver.saveToFile(
      filename: filename,
      data: _data.imageData!,
    );
    if (path != null) {
      SnackBarUtil.show(context, 'Saved to $path');
    }
  }

  Widget _buildHtmlResponseBody() {
    final htmlContent = _data.htmlContent ?? '';

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
          onPressed:
              () => ClipboardUtil.copy(
                htmlContent,
                context: context,
                snackBarMessage: 'HTML copied to clipboard',
              ),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy HTML'),
        ),
      ],
    );
  }

  Widget _buildBodyView(dynamic body) {
    final theme = TalkerThemeProvider.of(context);

    if (body == null) {
      return _EmptyState(
        message: 'No body',
        cardColor: theme.cardColor,
        textColor: theme.textColor,
      );
    }

    if (body is Map || body is List) {
      return SizedBox(
        height: 400,
        child: SearchableJsonViewer(
          data: body,
          initiallyExpanded: false,
          jsonSoftWrapTextValueAtWidth: _jsonWrapWidth,
        ),
      );
    }

    return _MonospaceTextBox(text: body.toString(), cardColor: theme.cardColor);
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final textColor = TalkerThemeProvider.of(context).textColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Padding(
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
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = TalkerThemeProvider.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textColor = TalkerThemeProvider.of(context).textColor;

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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.textColor});

  final String title;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}

class _HeadersList extends StatelessWidget {
  const _HeadersList({required this.entries, required this.cardColor});

  final List<MapEntry<String, String>> entries;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
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
            entries.map((entry) {
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
                        text: entry.value,
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.cardColor,
    required this.textColor,
  });

  final String message;
  final Color cardColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Green monospace text block used for plain-text bodies.
class _MonospaceTextBox extends StatelessWidget {
  const _MonospaceTextBox({required this.text, required this.cardColor});

  final String text;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: Colors.green[300],
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Orange info banner explaining that auth headers are masked.
class _AuthHiddenBanner extends StatelessWidget {
  const _AuthHiddenBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              'Authorization headers are hidden. '
              'Toggle "Show Full" to see all values.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
