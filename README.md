# Talker Dio Logger Plus

Advanced and feature-rich Dio HTTP client logger built on top of [Talker](https://pub.dev/packages/talker). This package extends the basic `talker_dio_logger` with powerful features for debugging HTTP requests.

## Features

### 🚀 Core Features
- **cURL Command Generation** - Copy requests as cURL with option to hide sensitive data
- **Interactive JSON Viewer** - Searchable, collapsible JSON viewer with syntax highlighting
- **Smart Truncation** - Automatically truncate large payloads while preserving full data for detail view
- **Multi-format Response Support** - JSON, HTML, Image, and plain text handling

### 🔒 Security Features
- **Hidden Headers** - Automatically hide sensitive headers like Authorization, API keys
- **Safe cURL Export** - Export cURL commands with hidden auth tokens
- **Bearer Token Masking** - Show `Bearer *****` instead of actual token

### 🖼️ Content Type Handling
- **JSON** - Interactive viewer with search and syntax highlighting
- **Images** - Inline preview for small images, tap to view for large images
- **HTML** - Preview with option to view full rendered content
- **Text** - Plain text display with full content support

### 📦 Export & Download
- **Download as ZIP** - Export request/response as a ZIP file (iOS/Android/Web compatible)
- **Share** - Share logs via system share dialog
- **Copy** - Copy individual sections or full cURL command
- **Pluggable File Saver** - Customize or disable file saving behavior

### 📱 Detail View Features
- **Tabbed Interface** - Overview, Request, Response, and cURL tabs
- **Search in JSON** - Find specific keys or values with highlighting
- **Full Headers View** - See all request and response headers
- **Response Time** - Track request duration

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  talker_dio_logger_plus: ^1.0.4
```

## Quick Start

```dart
import 'package:dio/dio.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_dio_logger_plus/talker_dio_logger_plus.dart';

void main() {
  final talker = Talker();
  
  final logger = AdvancedDioLogger(
    talker: talker,
    settings: const AdvancedDioLoggerSettings(
      printRequestData: true,
      printResponseData: true,
      printResponseTime: true,
      hiddenHeaders: {'authorization', 'x-api-key'},
      hideAuthorizationValue: true,
    ),
  );
  
  final dio = Dio();
  dio.interceptors.add(logger);
}
```

## Configuration

### AdvancedDioLoggerSettings

```dart
AdvancedDioLoggerSettings(
  // Enable/Disable
  enabled: true,
  logLevel: LogLevel.debug,
  
  // Print settings
  printRequestData: true,
  printRequestHeaders: true,
  printRequestExtra: false,
  printResponseData: true,
  printResponseHeaders: true,
  printResponseMessage: true,
  printResponseTime: true,
  printErrorData: true,
  printErrorHeaders: true,
  printErrorMessage: true,
  
  // Security
  hiddenHeaders: {'authorization', 'x-api-key', 'api-key'},
  hideAuthorizationValue: true,
  
  // Truncation (in bytes)
  truncateThreshold: 100 * 1024,  // 100KB
  maxDisplaySize: 1024 * 1024,    // 1MB
  imagePreviewThreshold: 500 * 1024, // 500KB
  maxInlineJsonLines: 20,
  
  // Feature flags
  enableCurlGeneration: true,
  enableJsonViewer: true,
  enableImagePreview: true,
  enableHtmlPreview: true,
  enableDownload: true,
  
  // Custom file saver (optional)
  fileSaver: const DefaultFileSaver(), // or NoOpFileSaver() or custom
  
  // Filters
  requestFilter: (options) => true,
  responseFilter: (response) => true,
  errorFilter: (exception) => true,
)
```

## Using with TalkerScreen

To use the custom HTTP log cards in TalkerScreen:

```dart
TalkerScreen(
  talker: talker,
  itemsBuilder: (context, data) {
    if (isAdvancedHttpLog(data)) {
      return HttpLogCard(
        data: data,
        expanded: true,
      );
    }
    // Return default card for other log types
    return TalkerDataCard(
      data: data,
      color: data.getFlutterColor(theme),
      backgroundColor: theme.cardColor,
    );
  },
)
```

## Theme Support

### TalkerThemeProvider

The package uses `TalkerThemeProvider` (an `InheritedWidget`) to provide consistent theming across all screens without prop drilling. When you navigate to detail screens, the theme is automatically available to all child widgets.

The `HttpLogCard` automatically wraps navigation with `TalkerThemeProvider`, so child screens like `FullScreenImageViewer` and `FullScreenHtmlPreview` can access the theme via:

```dart
final theme = TalkerThemeProvider.of(context);
```

### Custom Theme

You can customize the theme by passing a `TalkerScreenTheme` to `HttpLogCard`:

```dart
HttpLogCard(
  data: data,
  expanded: true,
  theme: TalkerScreenTheme(
    backgroundColor: Colors.black,
    cardColor: Color(0xFF1E1E1E),
    textColor: Colors.white,
    // ... other theme properties
  ),
)
```

### Accessing Theme in Custom Widgets

If you're building custom widgets that need access to the theme:

```dart
class MyCustomWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get theme from the nearest TalkerThemeProvider ancestor
    final theme = TalkerThemeProvider.of(context);
    
    // Use maybeOf if you want null instead of default theme
    final themeOrNull = TalkerThemeProvider.maybeOf(context);
    
    return Container(
      color: theme.backgroundColor,
      child: Text('Hello', style: TextStyle(color: theme.textColor)),
    );
  }
}
```

## cURL Generation

### Copy cURL with Hidden Auth
```dart
final log = data as AdvancedDioRequestLog;
final safeCurl = log.curlCommandSafe;
// Output: curl -X POST 'https://api.example.com' -H 'Authorization: Bearer [HIDDEN]'
```

### Copy Full cURL
```dart
final fullCurl = log.curlCommandFull;
// Output: curl -X POST 'https://api.example.com' -H 'Authorization: Bearer actual_token'
```

## JSON Viewer

The `SearchableJsonViewer` widget provides:
- Expandable/collapsible nodes
- Search with highlighting
- Copy entire JSON
- Syntax highlighting for different types

## Custom File Saver

The package provides a pluggable file saving system through `FileSaverInterface`. This allows you to:

- Use the default implementation (`DefaultFileSaver`)
- Disable file operations (`NoOpFileSaver`)
- Provide your own custom implementation

### Default Behavior

By default, the package uses `DefaultFileSaver` which requires `path_provider`, `archive`, and `share_plus` packages.

### Disable File Saving

If you don't need file saving/sharing functionality:

```dart
final logger = AdvancedDioLogger(
  settings: AdvancedDioLoggerSettings(
    fileSaver: const NoOpFileSaver(),
  ),
);
```

### Custom Implementation

Create your own file saver by implementing `FileSaverInterface`:

```dart
class MyCustomFileSaver implements FileSaverInterface {
  @override
  Future<String?> saveToFile({
    required String filename,
    required dynamic data,
    String? directory,
  }) async {
    // Your custom save logic
  }

  @override
  Future<String?> saveHttpLogToZip(HttpLogData logData, {String? filename}) async {
    // Your custom ZIP creation logic
  }

  @override
  Future<void> shareFile({required String filepath, String? subject, String? text}) async {
    // Your custom share logic
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    // Your custom text share logic
  }

  @override
  Future<void> saveAndShareHttpLog(HttpLogData logData) async {
    // Your custom save and share logic
  }

  @override
  Uint8List? getBytes(dynamic data) {
    // Convert data to bytes
  }
}

// Use it
final logger = AdvancedDioLogger(
  settings: AdvancedDioLoggerSettings(
    fileSaver: MyCustomFileSaver(),
  ),
);
```

## Content Type Detection

The logger automatically detects content types:
- **JSON**: `application/json`, `text/json`
- **HTML**: `text/html`, `application/xhtml+xml`
- **Images**: `image/jpeg`, `image/png`, `image/gif`, etc.
- **XML**: `text/xml`, `application/xml`
- **Text**: `text/plain`

## Size Handling

| Size | Behavior |
|------|----------|
| < 100KB | Full display in list |
| 100KB - 1MB | Truncated in list, full in detail |
| > 1MB | Truncated with download option |
| Images < 500KB | Inline preview |
| Images > 500KB | Tap to view |

## Platform Support

| Feature | iOS | Android | Web |
|---------|-----|---------|-----|
| cURL Generation | ✅ | ✅ | ✅ |
| JSON Viewer | ✅ | ✅ | ✅ |
| Image Preview | ✅ | ✅ | ✅ |
| Download ZIP | ✅ | ✅ | ⚠️* |
| Share | ✅ | ✅ | ⚠️* |

*Web has limited file system access

## License

MIT License
