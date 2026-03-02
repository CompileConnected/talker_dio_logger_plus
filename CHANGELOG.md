# Changelog

## 1.0.6

### Improvements
- **Memory optimization**: Response bodies are now truncated at intercept time via `_prepareResponseBody()` before storage in Talker history, preventing unbounded memory growth from large HTTP payloads
- **Cached text generation**: `generateTextMessage()` caches its result in `_cachedTextMessage` to avoid re-encoding large response bodies on every Talker history render
- **HTML content separation**: HTML responses now stored in dedicated `htmlContent` field (instead of `responseBody`) to avoid duplicate in-memory copies; `WebViewPreview` reads from `htmlContent` directly
- **Binary data sentinel**: Binary/unknown response types replaced with a small human-readable sentinel string (e.g., `"[Binary data — 4.20 MB]"`) instead of storing the full payload
- **Per-content-type display limits**: Replaced flat truncation threshold with `DisplayLimitRegistry` — a per-content-type registry mapping `HttpContentType` to `DisplayLimit` (maxBytes, maxLines, enablePreview)
- **Immutable display limit registry**: `DisplayLimitRegistry` uses `Map.unmodifiable` internally; all instances are effectively immutable after construction
- **Display limit clamping**: `DisplayLimit` factory constructor clamps values to safe ranges (1 KB – 100 MB for bytes, 1 – 1000 for lines)
- **Crash-safe interceptor**: All three interceptor hooks (`onRequest`, `onResponse`, `onError`) wrap both filter execution and log creation in separate try/catch blocks with `debugPrint` fallback — the interceptor never throws
- **Decoupled header masking**: `HeaderMasker` now has two API methods — `mask()` (raw params, used by `CurlGenerator`) and `maskFromSettings()` (convenience wrapper, used by factory functions) — so `CurlGenerator` does not depend on `AdvancedDioLoggerSettings`
- **Settings baked into logs**: Each `AdvancedDioLog` carries the full `AdvancedDioLoggerSettings` snapshot, so the UI layer reads feature flags and display limits directly from the log without external dependencies
- **JSON soft wrap**: Added `jsonSoftWrapTextValueAtWidth` setting to constrain string value width in `SearchableJsonViewer`
- **Runtime settings update**: Added `updateSettings()` method to `AdvancedDioLogger` for changing settings without recreating the interceptor
- **Line-numbered preview**: `HttpLogCard` response body preview now shows line numbers with a vertical gutter separator
- **Response body preview guards**: Card preview checks `maxBytes` first and shows "too large for preview" message; then checks `maxLines` and truncates with "tap Detail" hint


## 1.0.0

### Features
- Initial release
- **cURL Generation**: Generate cURL commands from HTTP requests
  - Safe mode with hidden authorization headers
  - Full mode with all values visible
- **Interactive JSON Viewer**: Searchable JSON viewer with syntax highlighting
  - Expand/collapse nodes
  - Search with highlighting
  - Copy entire JSON
- **Smart Data Truncation**: Automatic truncation of large payloads
  - Configurable per-content-type display limits via `DisplayLimitRegistry`
  - Full content available in detail view
- **Multi-format Response Support**:
  - JSON with interactive viewer
  - HTML with WebView preview (inline + full-screen)
  - Images with inline/full preview and pinch-to-zoom
  - Plain text
- **Security Features**:
  - Hidden headers (Authorization, API keys, etc.)
  - Bearer token masking
  - Safe cURL export
- **Export & Download**:
  - Download as ZIP file (request.txt, request_body, response.txt, response_body)
  - Share via system dialog
  - Copy individual sections
  - Pluggable `FileSaverInterface` with `DefaultFileSaver` and `NoOpFileSaver`
- **Detail View**:
  - Tabbed interface (Overview, Request, Response)
  - Full headers view with color coding
  - Response time tracking
  - Collapsible sections
- **Theme Support**:
  - `TalkerThemeProvider` InheritedWidget for theme propagation
  - Respects `TalkerScreenTheme.logColors` for status colors
- **Talker Compatibility**:
  - Runtime detection of Talker v4 vs v5
  - Automatic key registration on v5+
  - Custom `AnsiPen` configurations for console output
