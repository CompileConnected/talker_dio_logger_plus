import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:talker_dio_logger_plus/src/models/content_type_detector.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/utils/file_saver_interface.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';

/// Default implementation of [FileSaverInterface].
///
/// Uses path_provider, archive, and share_plus packages for
/// file operations. If you want to avoid these dependencies,
/// provide your own implementation of [FileSaverInterface].
class DefaultFileSaver implements FileSaverInterface {
  const DefaultFileSaver();

  @override
  Future<String?> saveToFile({
    required String filename,
    required dynamic data,
    String? directory,
  }) async {
    try {
      final dir = directory ?? await _getDefaultDirectory();
      if (dir == null) return null;

      final file = File('$dir/$filename');

      if (data is Uint8List) {
        await file.writeAsBytes(data);
      } else if (data is List<int>) {
        await file.writeAsBytes(Uint8List.fromList(data));
      } else if (data is String) {
        await file.writeAsString(data);
      } else {
        final jsonString = const JsonEncoder.withIndent('  ').convert(data);
        await file.writeAsString(jsonString);
      }

      return file.path;
    } catch (e) {
      debugPrint('DefaultFileSaver error: $e');
      return null;
    }
  }

  @override
  Future<String?> saveHttpLogToZip(
    HttpLogData logData, {
    String? filename,
  }) async {
    try {
      final dir = await _getDefaultDirectory();
      if (dir == null) return null;

      final archive = Archive();
      final timestamp = logData.timestamp.millisecondsSinceEpoch;
      final baseName = filename ?? 'http_log_$timestamp';

      // Add request info
      final requestInfo = _buildRequestInfo(logData);
      archive.addFile(
        ArchiveFile(
          '$baseName/request.txt',
          requestInfo.length,
          utf8.encode(requestInfo),
        ),
      );

      // Add request body if exists
      if (logData.requestBody != null) {
        final requestBody = logData.requestBody;
        final requestBodyStr = _convertToString(requestBody);
        archive.addFile(
          ArchiveFile(
            '$baseName/request_body.json',
            requestBodyStr.length,
            utf8.encode(requestBodyStr),
          ),
        );
      }

      // Add response info
      final responseInfo = _buildResponseInfo(logData);
      archive.addFile(
        ArchiveFile(
          '$baseName/response.txt',
          responseInfo.length,
          utf8.encode(responseInfo),
        ),
      );

      // Add response body
      if (logData.responseBody != null) {
        final responseBody = logData.responseBody;

        if (logData.isImage && logData.imageData != null) {
          final ext = ContentTypeDetector.getImageExtension(
            logData.responseHeaders?['content-type']?.first,
          );
          archive.addFile(
            ArchiveFile(
              '$baseName/response_body$ext',
              logData.imageData!.length,
              logData.imageData!,
            ),
          );
        } else {
          final ext = ContentTypeDetector.getFileExtension(logData.contentType);
          final responseBodyStr = _convertToString(responseBody);
          archive.addFile(
            ArchiveFile(
              '$baseName/response_body$ext',
              responseBodyStr.length,
              utf8.encode(responseBodyStr),
            ),
          );
        }
      }

      // Create ZIP file
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      final zipFile = File('$dir/$baseName.zip');
      await zipFile.writeAsBytes(zipData);

      return zipFile.path;
    } catch (e) {
      debugPrint('DefaultFileSaver.saveHttpLogToZip error: $e');
      return null;
    }
  }

  @override
  Future<void> shareFile({
    required String filepath,
    String? subject,
    String? text,
  }) async {
    try {
      await _shareFiles([XFile(filepath)], subject: subject, text: text);
    } catch (e) {
      debugPrint('DefaultFileSaver.shareFile error: $e');
    }
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    try {
      await _shareTextInternal(text, subject: subject);
    } catch (e) {
      debugPrint('DefaultFileSaver.shareText error: $e');
    }
  }

  @override
  Future<void> saveAndShareHttpLog(HttpLogData logData) async {
    final path = await saveHttpLogToZip(logData);
    if (path != null) {
      await shareFile(
        filepath: path,
        subject: 'HTTP Log - ${logData.method} ${logData.path}',
      );
    }
  }

  @override
  Uint8List? getBytes(dynamic data) {
    if (data == null) return null;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));
    return Uint8List.fromList(utf8.encode(data.toString()));
  }

  // Private helper methods

  Future<void> _shareFiles(
    List<XFile> files, {
    String? subject,
    String? text,
  }) async {
    // ignore: deprecated_member_use
    await Share.shareXFiles(files, subject: subject, text: text);
  }

  Future<void> _shareTextInternal(String text, {String? subject}) async {
    // ignore: deprecated_member_use
    await Share.share(text, subject: subject);
  }

  Future<String?> _getDefaultDirectory() async {
    try {
      if (kIsWeb) {
        return null; // Web doesn't support file system access
      }

      final directory = await getApplicationDocumentsDirectory();
      final talkerDir = Directory('${directory.path}/talker_logs');
      if (!await talkerDir.exists()) {
        await talkerDir.create(recursive: true);
      }
      return talkerDir.path;
    } catch (e) {
      debugPrint('DefaultFileSaver._getDefaultDirectory error: $e');
      return null;
    }
  }

  String _buildRequestInfo(HttpLogData logData) {
    final buffer = StringBuffer();
    buffer.writeln('=== HTTP Request ===');
    buffer.writeln('Method: ${logData.method}');
    buffer.writeln('URL: ${logData.formattedUrl}');
    buffer.writeln('Timestamp: ${logData.timestamp.toIso8601String()}');
    buffer.writeln();

    if (logData.requestHeaders != null && logData.requestHeaders!.isNotEmpty) {
      buffer.writeln('Headers:');
      logData.requestHeaders!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln();
    }

    if (logData.requestQueryParams != null &&
        logData.requestQueryParams!.isNotEmpty) {
      buffer.writeln('Query Parameters:');
      logData.requestQueryParams!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    return buffer.toString();
  }

  String _buildResponseInfo(HttpLogData logData) {
    final buffer = StringBuffer();
    buffer.writeln('=== HTTP Response ===');
    buffer.writeln(
      'Status: ${logData.statusCode} ${logData.statusMessage ?? ""}',
    );
    if (logData.responseTime != null) {
      buffer.writeln('Response Time: ${logData.responseTime}ms');
    }
    buffer.writeln('Content Type: ${logData.contentType.name}');
    if (logData.contentLength != null) {
      buffer.writeln(
        'Content Length: ${SizeCalculator.formatBytes(logData.contentLength!)}',
      );
    }
    buffer.writeln();

    if (logData.responseHeaders != null &&
        logData.responseHeaders!.isNotEmpty) {
      buffer.writeln('Headers:');
      logData.responseHeaders!.forEach((key, values) {
        buffer.writeln('  $key: ${values.join(", ")}');
      });
    }

    if (logData.error != null) {
      buffer.writeln();
      buffer.writeln('Error: ${logData.error}');
    }

    return buffer.toString();
  }

  String _convertToString(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
