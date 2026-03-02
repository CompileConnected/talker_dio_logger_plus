import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'http_body_type.dart';

/// Utility class to detect content type from HTTP responses.
class ContentTypeDetector {
  /// Detect content type from Response
  static HttpBodyType detectFromResponse(Response response) {
    final contentTypeHeader = response.headers.value('content-type');
    return detectFromContentType(contentTypeHeader, response.data);
  }

  /// Detect content type from headers and data
  static HttpBodyType detectFromContentType(
    String? contentTypeHeader,
    dynamic data,
  ) {
    if (contentTypeHeader != null) {
      final mimeType = contentTypeHeader.split(';').first.trim().toLowerCase();
      final result = _bodyTypeFromMime(mimeType);
      if (result != HttpBodyType.unknown) return result;
    }

    // Fallback: try to detect from data type
    return _detectFromData(data);
  }

  /// Map a MIME type string to an [HttpBodyType].
  static HttpBodyType _bodyTypeFromMime(String mimeType) {
    // JSON variants
    if (mimeType == 'application/json' ||
        mimeType == 'application/ld+json' ||
        mimeType == 'text/json' ||
        mimeType.contains('+json')) {
      return HttpBodyType.json;
    }
    // HTML
    if (mimeType == 'text/html' || mimeType == 'application/xhtml+xml') {
      return HttpBodyType.html;
    }
    // XML variants
    if (mimeType == 'text/xml' ||
        mimeType == 'application/xml' ||
        mimeType.contains('+xml')) {
      return HttpBodyType.xml;
    }
    // Image (any image/* type)
    if (mimeType.startsWith('image/')) {
      return HttpBodyType.image;
    }
    // Generic text
    if (mimeType.startsWith('text/')) {
      return HttpBodyType.text;
    }
    return HttpBodyType.unknown;
  }

  /// Try to detect content type from the data itself.
  static HttpBodyType _detectFromData(dynamic data) {
    if (data == null) return HttpBodyType.unknown;

    if (data is Map || data is List && data is! List<int>) {
      return HttpBodyType.json;
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return HttpBodyType.json;
      }
      if (trimmed.startsWith('<!DOCTYPE') ||
          trimmed.startsWith('<html') ||
          trimmed.startsWith('<HTML')) {
        return HttpBodyType.html;
      }
      if (trimmed.startsWith('<?xml')) {
        return HttpBodyType.xml;
      }
      return HttpBodyType.text;
    }

    if (data is List<int>) {
      // Delegate magic-byte detection to the `mime` package which already
      // covers PNG, JPEG, GIF, WebP, TIFF, HEIC, PDF, audio, video, etc.
      final detected = lookupMimeType('', headerBytes: data);
      if (detected != null) {
        return _bodyTypeFromMime(detected);
      }
      return HttpBodyType.unknown;
    }

    return HttpBodyType.unknown;
  }

  /// Get file extension for content type.
  static String getFileExtension(HttpBodyType contentType) {
    switch (contentType) {
      case HttpBodyType.json:
        return '.json';
      case HttpBodyType.html:
        return '.html';
      case HttpBodyType.xml:
        return '.xml';
      case HttpBodyType.text:
        return '.txt';
      case HttpBodyType.image:
        return '.bin'; // Will be overridden by actual mime type
      case HttpBodyType.unknown:
        return '.bin';
    }
  }

  /// Get file extension from a MIME type string (e.g. `image/png` → `.png`).
  static String getImageExtension(String? mimeType) {
    if (mimeType == null) return '.bin';
    final mime = mimeType.split(';').first.trim().toLowerCase();
    final ext = extensionFromMime(mime);
    if (ext != null) return '.$ext';
    return '.bin';
  }
}
