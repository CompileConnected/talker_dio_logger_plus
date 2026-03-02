import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:talker_dio_logger_plus/src/ui/talker_theme_provider.dart';
import 'package:talker_dio_logger_plus/src/utils/clipboard_util.dart';

/// Widget to preview HTML content using an actual WebView
class WebViewPreview extends StatelessWidget {
  const WebViewPreview({
    super.key,
    required this.htmlContent,
    this.maxHeight = 200,
    this.onTap,
  });

  final String htmlContent;
  final double maxHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: maxHeight,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InAppWebView(
                initialData: InAppWebViewInitialData(data: htmlContent),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: false,
                  disableContextMenu: true,
                  transparentBackground: true,
                  supportZoom: false,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
            // HTML badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.html, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'HTML',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tap to preview label
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Tap to preview',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen HTML preview using InAppWebView
class FullScreenHtmlPreview extends StatefulWidget {
  const FullScreenHtmlPreview({
    super.key,
    required this.htmlContent,
    this.title,
  });

  final String htmlContent;
  final String? title;

  @override
  State<FullScreenHtmlPreview> createState() => _FullScreenHtmlPreviewState();
}

class _FullScreenHtmlPreviewState extends State<FullScreenHtmlPreview> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final theme = TalkerThemeProvider.of(context);
    final bgColor = theme.backgroundColor;
    final textColor = theme.textColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        title: Text(widget.title ?? 'HTML Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => _showSourceCode(context),
            tooltip: 'View Source',
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(data: widget.htmlContent),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              supportZoom: true,
              transparentBackground: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              setState(() => _isLoading = false);
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  void _showSourceCode(BuildContext context) {
    final theme = TalkerThemeProvider.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.textColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'HTML Source',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.copy, color: textColor),
                          onPressed: () {
                            ClipboardUtil.copy(
                              widget.htmlContent,
                              context: context,
                              snackBarMessage:
                                  'HTML source copied to clipboard',
                            );
                          },
                          tooltip: 'Copy source',
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textColor),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        widget.htmlContent,
                        style: const TextStyle(
                          color: Colors.green,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
