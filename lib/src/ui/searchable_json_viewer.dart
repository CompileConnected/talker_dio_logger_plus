import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'talker_theme_provider.dart';

/// A searchable and interactive JSON viewer widget
class SearchableJsonViewer extends StatefulWidget {
  const SearchableJsonViewer({
    super.key,
    required this.data,
    this.initiallyExpanded = true,
    this.searchController,
    this.highlightColor,
    this.backgroundColor,
    this.textColor,
    this.keyColor,
    this.stringColor,
    this.numberColor,
    this.boolColor,
    this.nullColor,
    this.onCopy,
    this.jsonSoftWrapTextValueAtWidth,
  });

  final dynamic data;
  final bool initiallyExpanded;
  final TextEditingController? searchController;
  final Color? highlightColor;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? keyColor;
  final Color? stringColor;
  final Color? numberColor;
  final Color? boolColor;
  final Color? nullColor;
  final VoidCallback? onCopy;

  /// Width at which to soft wrap string values (in logical pixels).
  /// When set, long string values will wrap at this width.
  /// Only affects string values, not keys or JSON structure.
  /// Set to `null` to disable wrapping (default - uses horizontal scroll).
  final double? jsonSoftWrapTextValueAtWidth;

  @override
  State<SearchableJsonViewer> createState() => _SearchableJsonViewerState();
}

class _SearchableJsonViewerState extends State<SearchableJsonViewer> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  final Set<String> _expandedPaths = {};
  final Set<String> _matchingPaths = {};
  List<String> _matchingPathsList = [];
  int _currentMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
    _searchController.addListener(_onSearchChanged);
    if (widget.initiallyExpanded) {
      _expandAll(widget.data, '');
    }
  }

  @override
  void dispose() {
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _matchingPaths.clear();
      _matchingPathsList.clear();
      _currentMatchIndex = 0;
      if (_searchQuery.length >= 2) {
        _findMatchingPaths(widget.data, '');
        _matchingPathsList = _matchingPaths.toList();
        // Expand all paths that contain matches
        for (final path in _matchingPaths) {
          _expandParentPaths(path);
        }
      }
    });
  }

  void _goToNextMatch() {
    if (_matchingPathsList.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchingPathsList.length;
    });
  }

  void _goToPreviousMatch() {
    if (_matchingPathsList.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matchingPathsList.length) %
          _matchingPathsList.length;
    });
  }

  void _expandAll(dynamic data, String path) {
    if (data is Map) {
      _expandedPaths.add(path);
      data.forEach((key, value) {
        _expandAll(value, '$path/$key');
      });
    } else if (data is List) {
      _expandedPaths.add(path);
      for (var i = 0; i < data.length; i++) {
        _expandAll(data[i], '$path[$i]');
      }
    }
  }

  void _collapseAll() {
    setState(() {
      _expandedPaths.clear();
    });
  }

  void _expandAllPaths() {
    setState(() {
      _expandAll(widget.data, '');
    });
  }

  void _findMatchingPaths(dynamic data, String path) {
    if (data is Map) {
      data.forEach((key, value) {
        final keyString = key.toString().toLowerCase();
        final childPath = '$path/$key';

        // Check if key alone matches
        if (keyString.contains(_searchQuery)) {
          _matchingPaths.add(childPath);
        }

        // Check if combined "key": value format matches (for primitive values)
        if (value is! Map && value is! List) {
          final valueStr = _formatValueForSearch(value);
          final combined = '"$keyString": $valueStr'.toLowerCase();
          if (combined.contains(_searchQuery)) {
            _matchingPaths.add(childPath);
          }
        }

        _findMatchingPaths(value, childPath);
      });
    } else if (data is List) {
      for (var i = 0; i < data.length; i++) {
        _findMatchingPaths(data[i], '$path[$i]');
      }
    } else {
      final valueString = data?.toString().toLowerCase() ?? '';
      if (valueString.contains(_searchQuery)) {
        _matchingPaths.add(path);
      }
    }
  }

  String _formatValueForSearch(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    return value.toString();
  }

  void _expandParentPaths(String path) {
    final parts = path.split('/');
    var currentPath = '';
    for (var i = 0; i < parts.length - 1; i++) {
      if (parts[i].isNotEmpty) {
        currentPath += '/${parts[i]}';
        _expandedPaths.add(currentPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final talkerTheme = TalkerThemeProvider.maybeOf(context);

    final colors = _JsonViewerColors(
      background:
          widget.backgroundColor ?? talkerTheme?.cardColor ?? Colors.grey[900]!,
      text: widget.textColor ?? talkerTheme?.textColor ?? Colors.white,
      key: widget.keyColor ?? Colors.purple[200]!,
      string: widget.stringColor ?? Colors.green[300]!,
      number: widget.numberColor ?? Colors.blue[300]!,
      bool: widget.boolColor ?? Colors.orange[300]!,
      nullValue: widget.nullColor ?? Colors.red[300]!,
      highlight: widget.highlightColor ?? Colors.yellow.withValues(alpha: 0.3),
    );

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(8),
          color: colors.background,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search JSON...',
                    hintStyle: TextStyle(
                      color: colors.text.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colors.text.withValues(alpha: 0.7),
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: colors.text.withValues(alpha: 0.7),
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                            : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colors.text.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.key),
                    ),
                  ),
                  style: TextStyle(color: colors.text),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.unfold_more,
                  color: colors.text.withValues(alpha: 0.7),
                ),
                onPressed: _expandAllPaths,
                tooltip: 'Expand All',
              ),
              IconButton(
                icon: Icon(
                  Icons.unfold_less,
                  color: colors.text.withValues(alpha: 0.7),
                ),
                onPressed: _collapseAll,
                tooltip: 'Collapse All',
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: colors.text.withValues(alpha: 0.7),
                ),
                onPressed: () {
                  final jsonString = const JsonEncoder.withIndent(
                    '  ',
                  ).convert(widget.data);
                  Clipboard.setData(ClipboardData(text: jsonString));
                  widget.onCopy?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON copied to clipboard')),
                  );
                },
                tooltip: 'Copy JSON',
              ),
            ],
          ),
        ),
        // Match count and navigation
        if (_searchQuery.length >= 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: colors.background,
            child: Row(
              children: [
                Text(
                  _matchingPathsList.isEmpty
                      ? '0 matches found'
                      : '${_currentMatchIndex + 1} of ${_matchingPathsList.length} matches',
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.keyboard_arrow_up,
                    size: 20,
                    color: colors.text.withValues(alpha: 0.7),
                  ),
                  onPressed:
                      _matchingPathsList.isEmpty ? null : _goToPreviousMatch,
                  tooltip: 'Previous Match',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: colors.text.withValues(alpha: 0.7),
                  ),
                  onPressed: _matchingPathsList.isEmpty ? null : _goToNextMatch,
                  tooltip: 'Next Match',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        // JSON content
        Expanded(
          child: Container(
            width: double.infinity,
            color: colors.background,
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicWidth(
                    child: _buildJsonView(widget.data, '', 0, colors),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJsonView(
    dynamic data,
    String path,
    int indent,
    _JsonViewerColors colors,
  ) {
    if (data is Map) {
      return _buildMapView(data, path, indent, colors);
    } else if (data is List) {
      return _buildListView(data, path, indent, colors);
    } else {
      return _buildValueView(data, path, colors);
    }
  }

  Widget _buildMapView(
    Map data,
    String path,
    int indent,
    _JsonViewerColors colors,
  ) {
    final isExpanded = _expandedPaths.contains(path);
    final entries = data.entries.toList();

    if (entries.isEmpty) {
      return Text('{}', style: TextStyle(color: colors.text));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedPaths.remove(path);
              } else {
                _expandedPaths.add(path);
              }
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 16,
                color: colors.text,
              ),
              Text(
                '{${entries.length}}',
                style: TextStyle(color: colors.text.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  entries.map((entry) {
                    final key = entry.key.toString();
                    final value = entry.value;
                    final childPath = '$path/$key';
                    final isMatch =
                        _matchingPaths.contains(childPath) ||
                        (_searchQuery.length >= 2 &&
                            key.toLowerCase().contains(_searchQuery));
                    final isCurrentMatch =
                        _matchingPathsList.isNotEmpty &&
                        _currentMatchIndex < _matchingPathsList.length &&
                        _matchingPathsList[_currentMatchIndex] == childPath;

                    return Container(
                      decoration: BoxDecoration(
                        color:
                            isCurrentMatch
                                ? colors.highlight.withValues(alpha: 0.6)
                                : (isMatch ? colors.highlight : null),
                        border:
                            isCurrentMatch
                                ? Border.all(color: Colors.orange, width: 2)
                                : null,
                        borderRadius:
                            isCurrentMatch ? BorderRadius.circular(4) : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHighlightedText('"$key": ', colors.key, colors),
                          Expanded(
                            child: _buildJsonView(
                              value,
                              childPath,
                              indent + 1,
                              colors,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildListView(
    List data,
    String path,
    int indent,
    _JsonViewerColors colors,
  ) {
    final isExpanded = _expandedPaths.contains(path);

    if (data.isEmpty) {
      return Text('[]', style: TextStyle(color: colors.text));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedPaths.remove(path);
              } else {
                _expandedPaths.add(path);
              }
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 16,
                color: colors.text,
              ),
              Text(
                '[${data.length}]',
                style: TextStyle(color: colors.text.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(data.length, (index) {
                final childPath = '$path[$index]';
                final isMatch = _matchingPaths.contains(childPath);
                final isCurrentMatch =
                    _matchingPathsList.isNotEmpty &&
                    _currentMatchIndex < _matchingPathsList.length &&
                    _matchingPathsList[_currentMatchIndex] == childPath;

                return Container(
                  decoration: BoxDecoration(
                    color:
                        isCurrentMatch
                            ? colors.highlight.withValues(alpha: 0.6)
                            : (isMatch ? colors.highlight : null),
                    border:
                        isCurrentMatch
                            ? Border.all(color: Colors.orange, width: 2)
                            : null,
                    borderRadius:
                        isCurrentMatch ? BorderRadius.circular(4) : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[$index]: ',
                        style: TextStyle(
                          color: colors.text.withValues(alpha: 0.7),
                        ),
                      ),
                      Expanded(
                        child: _buildJsonView(
                          data[index],
                          childPath,
                          indent + 1,
                          colors,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildValueView(dynamic data, String path, _JsonViewerColors colors) {
    final isMatch = _matchingPaths.contains(path);
    final isCurrentMatch =
        _matchingPathsList.isNotEmpty &&
        _currentMatchIndex < _matchingPathsList.length &&
        _matchingPathsList[_currentMatchIndex] == path;

    Color color;
    String text;
    bool isString = false;

    if (data == null) {
      color = colors.nullValue;
      text = 'null';
    } else if (data is bool) {
      color = colors.bool;
      text = data.toString();
    } else if (data is num) {
      color = colors.number;
      text = data.toString();
    } else if (data is String) {
      color = colors.string;
      text = '"$data"';
      isString = true;
    } else {
      color = colors.text;
      text = data.toString();
    }

    Widget textWidget = _buildHighlightedText(text, color, colors);

    // Apply soft wrap only to string values when width is specified
    if (isString && widget.jsonSoftWrapTextValueAtWidth != null) {
      textWidget = SizedBox(
        width: widget.jsonSoftWrapTextValueAtWidth,
        child: textWidget,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color:
            isCurrentMatch
                ? colors.highlight.withValues(alpha: 0.6)
                : (isMatch ? colors.highlight : null),
        border:
            isCurrentMatch ? Border.all(color: Colors.orange, width: 2) : null,
        borderRadius: isCurrentMatch ? BorderRadius.circular(4) : null,
      ),
      child: textWidget,
    );
  }

  Widget _buildHighlightedText(
    String text,
    Color color,
    _JsonViewerColors colors,
  ) {
    if (_searchQuery.length < 2) {
      return Text(text, style: TextStyle(color: color));
    }

    final lowerText = text.toLowerCase();
    final matches = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(_searchQuery, start);
      if (index == -1) {
        matches.add(
          TextSpan(text: text.substring(start), style: TextStyle(color: color)),
        );
        break;
      }

      if (index > start) {
        matches.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: color),
          ),
        );
      }

      matches.add(
        TextSpan(
          text: text.substring(index, index + _searchQuery.length),
          style: TextStyle(
            color: color,
            backgroundColor: colors.highlight,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + _searchQuery.length;
    }

    return RichText(text: TextSpan(children: matches));
  }
}

class _JsonViewerColors {
  const _JsonViewerColors({
    required this.background,
    required this.text,
    required this.key,
    required this.string,
    required this.number,
    required this.bool,
    required this.nullValue,
    required this.highlight,
  });

  final Color background;
  final Color text;
  final Color key;
  final Color string;
  final Color number;
  final Color bool;
  final Color nullValue;
  final Color highlight;
}
