import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:talker_dio_logger_plus/src/ui/talker_theme_provider.dart';

/// Widget to preview HTML content
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
    // For simple preview, we'll show a styled preview box
    // A full web view would require platform-specific implementation
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: maxHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildHtmlPreview(),
                ),
              ),
            ),
            // Overlay with tap indicator
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

  Widget _buildHtmlPreview() {
    // Simple text extraction from HTML for preview
    final textContent = _extractTextFromHtml(htmlContent);
    return Text(
      textContent,
      style: TextStyle(color: Colors.grey[800], fontSize: 12),
    );
  }

  String _extractTextFromHtml(String html) {
    // Simple HTML tag removal for preview
    return html
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Full screen HTML preview
class FullScreenHtmlPreview extends StatelessWidget {
  const FullScreenHtmlPreview({
    super.key,
    required this.htmlContent,
    this.title,
  });

  final String htmlContent;
  final String? title;

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
        title: Text(title ?? 'HTML Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () => _showSourceCode(context),
            tooltip: 'View Source',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // For now, show the raw HTML with syntax highlighting
    // A full implementation would use webview_flutter for mobile
    // and iframe for web
    if (kIsWeb) {
      return _buildWebPreview(context);
    } else {
      return _buildMobilePreview(context);
    }
  }

  Widget _buildWebPreview(BuildContext context) {
    // On web, we can potentially use an iframe
    // For simplicity, show raw HTML
    return _buildHtmlSource(context);
  }

  Widget _buildMobilePreview(BuildContext context) {
    // On mobile, ideally use webview_flutter
    // For simplicity, show raw HTML with basic rendering
    return _buildHtmlSource(context);
  }

  Widget _buildHtmlSource(BuildContext context) {
    final theme = TalkerThemeProvider.of(context);
    return Container(
      color: theme.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          htmlContent,
          style: TextStyle(
            color: theme.textColor,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
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
                        htmlContent,
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
