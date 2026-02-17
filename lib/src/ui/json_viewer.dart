import 'dart:convert';

import 'package:flutter/material.dart';

/// Simple JSON viewer widget for inline display
class JsonViewer extends StatelessWidget {
  const JsonViewer({
    super.key,
    required this.data,
    this.maxLines,
    this.textColor,
    this.backgroundColor,
    this.fontSize = 12,
    this.showExpandButton = true,
    this.onExpandTap,
  });

  final dynamic data;
  final int? maxLines;
  final Color? textColor;
  final Color? backgroundColor;
  final double fontSize;
  final bool showExpandButton;
  final VoidCallback? onExpandTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveTextColor =
        textColor ?? (isDark ? Colors.green[300] : Colors.green[800]);
    final effectiveBgColor =
        backgroundColor ?? (isDark ? Colors.grey[900] : Colors.grey[100]);

    String jsonString;
    try {
      jsonString = const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      jsonString = data.toString();
    }

    final lines = jsonString.split('\n');
    final needsTruncation = maxLines != null && lines.length > maxLines!;
    final displayText =
        needsTruncation ? lines.take(maxLines!).join('\n') : jsonString;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            displayText,
            style: TextStyle(
              color: effectiveTextColor,
              fontSize: fontSize,
              fontFamily: 'monospace',
            ),
          ),
          if (needsTruncation && showExpandButton) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onExpandTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Show ${lines.length - maxLines!} more lines',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Expandable JSON viewer that can show truncated or full JSON
class ExpandableJsonViewer extends StatefulWidget {
  const ExpandableJsonViewer({
    super.key,
    required this.data,
    this.initialMaxLines = 20,
    this.textColor,
    this.backgroundColor,
  });

  final dynamic data;
  final int initialMaxLines;
  final Color? textColor;
  final Color? backgroundColor;

  @override
  State<ExpandableJsonViewer> createState() => _ExpandableJsonViewerState();
}

class _ExpandableJsonViewerState extends State<ExpandableJsonViewer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return JsonViewer(
      data: widget.data,
      maxLines: _expanded ? null : widget.initialMaxLines,
      textColor: widget.textColor,
      backgroundColor: widget.backgroundColor,
      onExpandTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
    );
  }
}

