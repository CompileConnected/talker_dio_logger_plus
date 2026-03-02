import 'package:dio/dio.dart';

import 'http_log_data.dart';

/// Utility class to detect content type from HTTP responses
class ContentTypeDetector {
  /// Common image MIME types
  static const _imageMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/svg+xml',
    'image/x-icon',
    'image/tiff',
  ];

  /// Common text-based MIME types
  static const _textMimeTypes = ['text/plain', 'text/csv'];

  /// Common HTML MIME types
  static const _htmlMimeTypes = ['text/html', 'application/xhtml+xml'];

  /// Common XML MIME types
  static const _xmlMimeTypes = ['text/xml', 'application/xml'];

  /// Common JSON MIME types
  static const _jsonMimeTypes = [
    'application/json',
    'application/ld+json',
    'application/vnd.api+json',
    'text/json',
  ];

  /// Detect content type from Response
  static HttpContentType detectFromResponse(Response response) {
    final contentTypeHeader = response.headers.value('content-type');
    return detectFromContentType(contentTypeHeader, response.data);
  }

  /// Detect content type from headers and data
  static HttpContentType detectFromContentType(
    String? contentTypeHeader,
    dynamic data,
  ) {
    if (contentTypeHeader != null) {
      final mimeType = contentTypeHeader.split(';').first.trim().toLowerCase();

      if (_jsonMimeTypes.any((type) => mimeType.contains(type))) {
        return HttpContentType.json;
      }
      if (_htmlMimeTypes.any((type) => mimeType.contains(type))) {
        return HttpContentType.html;
      }
      if (_xmlMimeTypes.any((type) => mimeType.contains(type))) {
        return HttpContentType.xml;
      }
      if (_textMimeTypes.any((type) => mimeType.contains(type))) {
        return HttpContentType.text;
      }
      if (_imageMimeTypes.any((type) => mimeType.contains(type))) {
        return HttpContentType.image;
      }
      if (mimeType.startsWith('application/octet-stream') ||
          mimeType.contains('binary')) {
        return HttpContentType.binary;
      }
    }

    // Fallback: try to detect from data type
    return _detectFromData(data);
  }

  /// Try to detect content type from the data itself
  static HttpContentType _detectFromData(dynamic data) {
    if (data == null) {
      return HttpContentType.unknown;
    }

    if (data is Map || data is List) {
      return HttpContentType.json;
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return HttpContentType.json;
      }
      if (trimmed.startsWith('<!DOCTYPE') ||
          trimmed.startsWith('<html') ||
          trimmed.startsWith('<HTML')) {
        return HttpContentType.html;
      }
      if (trimmed.startsWith('<?xml')) {
        return HttpContentType.xml;
      }
      return HttpContentType.text;
    }

    if (data is List<int>) {
      // Check for common image magic bytes
      if (data.length >= 8) {
        // PNG
        if (data[0] == 0x89 &&
            data[1] == 0x50 &&
            data[2] == 0x4E &&
            data[3] == 0x47) {
          return HttpContentType.image;
        }
        // JPEG
        if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
          return HttpContentType.image;
        }
        // GIF
        if (data[0] == 0x47 &&
            data[1] == 0x49 &&
            data[2] == 0x46 &&
            data[3] == 0x38) {
          return HttpContentType.image;
        }
        // WebP
        if (data.length >= 12 &&
            data[0] == 0x52 &&
            data[1] == 0x49 &&
            data[2] == 0x46 &&
            data[3] == 0x46 &&
            data[8] == 0x57 &&
            data[9] == 0x45 &&
            data[10] == 0x42 &&
            data[11] == 0x50) {
          return HttpContentType.image;
        }
      }
      return HttpContentType.binary;
    }

    return HttpContentType.unknown;
  }

  /// Get file extension for content type
  static String getFileExtension(HttpContentType contentType) {
    switch (contentType) {
      case HttpContentType.json:
        return '.json';
      case HttpContentType.html:
        return '.html';
      case HttpContentType.xml:
        return '.xml';
      case HttpContentType.text:
        return '.txt';
      case HttpContentType.image:
        return '.bin'; // Will be overridden by actual mime type
      case HttpContentType.binary:
        return '.bin';
      case HttpContentType.file:
        return '.bin';
      case HttpContentType.unknown:
        return '.txt';
    }
  }

  /// Get image extension from mime type
  static String getImageExtension(String? mimeType) {
    if (mimeType == null) return '.bin';
    final mime = mimeType.toLowerCase();
    if (mime.contains('jpeg') || mime.contains('jpg')) return '.jpg';
    if (mime.contains('png')) return '.png';
    if (mime.contains('gif')) return '.gif';
    if (mime.contains('webp')) return '.webp';
    if (mime.contains('bmp')) return '.bmp';
    if (mime.contains('svg')) return '.svg';
    if (mime.contains('ico') || mime.contains('icon')) return '.ico';
    if (mime.contains('tiff')) return '.tiff';
    return '.bin';
  }
}
