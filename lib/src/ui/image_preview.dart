import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:talker_dio_logger_plus/src/ui/talker_theme_provider.dart';
import 'package:talker_dio_logger_plus/src/utils/file_saver.dart';
import 'package:talker_dio_logger_plus/src/utils/file_saver_interface.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';

/// Widget to display image preview
class ImagePreview extends StatelessWidget {
  const ImagePreview({
    super.key,
    required this.imageData,
    this.maxHeight = 200,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.onSave,
    this.showSaveButton = true,
  });

  final Uint8List imageData;
  final double maxHeight;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final bool showSaveButton;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                imageData,
                fit: fit,
                errorBuilder: (context, error, stackTrace) {
                  return errorWidget ??
                      Container(
                        height: 100,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                },
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child:
                        frame != null
                            ? child
                            : placeholder ??
                                Container(
                                  height: 100,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                  );
                },
              ),
            ),
            // Size badge
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  SizeCalculator.formatBytes(imageData.length),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
            // Save button
            if (showSaveButton)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: onSave,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full screen image viewer
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imageData,
    this.title,
    this.mimeType,
    this.fileSaver,
  });

  final Uint8List imageData;
  final String? title;
  final String? mimeType;

  /// Custom file saver. If not provided, uses [DefaultFileSaver].
  final FileSaverInterface? fileSaver;

  FileSaverInterface get _fileSaver => fileSaver ?? const DefaultFileSaver();

  @override
  Widget build(BuildContext context) {
    final theme = TalkerThemeProvider.of(context);
    final bgColor = theme.backgroundColor;
    final textColor = theme.textColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        title: Text(title ?? 'Image Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _saveImage(context),
            tooltip: 'Save Image',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareImage(context),
            tooltip: 'Share Image',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            imageData,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image,
                      color: textColor.withValues(alpha: 0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: textColor.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: bgColor,
        child: Text(
          'Size: ${SizeCalculator.formatBytes(imageData.length)}',
          style: TextStyle(color: textColor.withValues(alpha: 0.6)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    final ext = mimeType != null ? _getExtension(mimeType!) : '.png';
    final filename = 'image_${DateTime.now().millisecondsSinceEpoch}$ext';

    final path = await _fileSaver.saveToFile(
      filename: filename,
      data: imageData,
    );

    if (path != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image saved to $path')));
    }
  }

  Future<void> _shareImage(BuildContext context) async {
    final ext = mimeType != null ? _getExtension(mimeType!) : '.png';
    final filename = 'image_${DateTime.now().millisecondsSinceEpoch}$ext';

    final path = await _fileSaver.saveToFile(
      filename: filename,
      data: imageData,
    );

    if (path != null) {
      await _fileSaver.shareFile(filepath: path, subject: 'Shared Image');
    }
  }

  String _getExtension(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime.contains('jpeg') || mime.contains('jpg')) return '.jpg';
    if (mime.contains('png')) return '.png';
    if (mime.contains('gif')) return '.gif';
    if (mime.contains('webp')) return '.webp';
    return '.png';
  }
}

/// Image placeholder widget for large images
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, required this.size, this.onTap});

  final int size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[600]!),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image, color: Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(
                'Image (${SizeCalculator.formatBytes(size)})',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to view',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
