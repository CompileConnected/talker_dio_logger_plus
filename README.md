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

### 📱 Detail View Features
- **Tabbed Interface** - Overview, Request, Response, and cURL tabs
- **Search in JSON** - Find specific keys or values with highlighting
- **Full Headers View** - See all request and response headers
- **Response Time** - Track request duration

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  talker_dio_logger_plus: ^1.0.0
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
const AdvancedDioLoggerSettings(
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

### Manual cURL Generation
```dart
// Safe (hidden auth)
final curl = CurlGenerator.generateSafe(
  requestOptions,
  hiddenHeaders: {'authorization', 'x-api-key'},
  hideAuthorizationValue: true,
);

// Full (all values visible)
final fullCurl = CurlGenerator.generateFull(requestOptions);
```

## JSON Viewer

The `SearchableJsonViewer` widget provides:
- Expandable/collapsible nodes
- Search with highlighting
- Copy entire JSON
- Syntax highlighting for different types

```dart
SearchableJsonViewer(
  data: jsonData,
  initiallyExpanded: true,
  highlightColor: Colors.yellow.withOpacity(0.3),
)
```

## Download & Share

### Download as ZIP
```dart
final path = await FileSaver.saveHttpLogToZip(httpLogData);
```

### Share
```dart
await FileSaver.saveAndShareHttpLog(httpLogData);
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

