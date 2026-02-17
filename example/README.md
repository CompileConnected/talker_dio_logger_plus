# Talker Dio Logger Plus - Example

A demo Flutter application showcasing the features of `talker_dio_logger_plus`.

## Features Demonstrated

- **HTTP Request Logging** - GET, POST with various content types
- **cURL Generation** - Copy requests as cURL with hidden auth tokens
- **Image Response Preview** - View image responses inline
- **HTML Response Preview** - View HTML responses with full-screen option
- **JSON Viewer** - Interactive, searchable JSON viewer
- **Theme Support** - Consistent theming via `TalkerThemeProvider`
- **Error Handling** - Capture and display HTTP errors

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Key Implementation Details

### Setting Up the Logger

```dart
final logger = AdvancedDioLogger(
  talker: _talker,
  settings: const AdvancedDioLoggerSettings(
    printRequestData: true,
    printResponseData: true,
    hiddenHeaders: {'authorization', 'x-api-key'},
    hideAuthorizationValue: true,
  ),
);

_dio.interceptors.add(logger);
```

### Using HttpLogCard with Theme

```dart
TalkerScreen(
  talker: _talker,
  theme: theme,
  itemsBuilder: (context, data) {
    if (isAdvancedHttpLog(data)) {
      // HttpLogCard automatically wraps child navigations with
      // TalkerThemeProvider for consistent theming
      return HttpLogCard(data: data, theme: theme);
    }
    return TalkerDataCard(data: data, ...);
  },
)
```

### Accessing Theme in Child Widgets

Child screens can access the theme without prop drilling:

```dart
final theme = TalkerThemeProvider.of(context);
```
