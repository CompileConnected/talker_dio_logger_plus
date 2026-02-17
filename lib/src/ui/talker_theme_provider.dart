import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// InheritedWidget to provide TalkerScreenTheme to descendant widgets
/// without prop drilling.
///
/// Wrap your widget tree with [TalkerThemeProvider] and access the theme
/// anywhere using [TalkerThemeProvider.of(context)] or [TalkerThemeProvider.maybeOf(context)].
///
/// Example:
/// ```dart
/// TalkerThemeProvider(
///   theme: myTheme,
///   child: HttpDetailScreen(...),
/// )
/// ```
///
/// Then in any descendant widget:
/// ```dart
/// final theme = TalkerThemeProvider.of(context);
/// ```
class TalkerThemeProvider extends InheritedWidget {
  const TalkerThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  final TalkerScreenTheme theme;

  /// Returns the [TalkerScreenTheme] from the nearest [TalkerThemeProvider] ancestor.
  /// Returns a default theme if no provider is found.
  static TalkerScreenTheme of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<TalkerThemeProvider>();
    return provider?.theme ?? const TalkerScreenTheme();
  }

  /// Returns the [TalkerScreenTheme] from the nearest [TalkerThemeProvider] ancestor,
  /// or null if no provider is found.
  static TalkerScreenTheme? maybeOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<TalkerThemeProvider>();
    return provider?.theme;
  }

  @override
  bool updateShouldNotify(TalkerThemeProvider oldWidget) {
    return theme != oldWidget.theme;
  }
}
