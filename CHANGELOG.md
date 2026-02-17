# Changelog

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
  - Configurable threshold (default 100KB)
  - Full content available in detail view
- **Multi-format Response Support**:
  - JSON with interactive viewer
  - HTML with preview
  - Images with inline/full preview
  - Plain text
- **Security Features**:
  - Hidden headers (Authorization, API keys, etc.)
  - Bearer token masking
  - Safe cURL export
- **Export & Download**:
  - Download as ZIP file
  - Share via system dialog
  - Copy individual sections
- **Detail View**:
  - Tabbed interface (Overview, Request, Response, cURL)
  - Full headers view
  - Response time tracking

