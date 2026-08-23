import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final String imageUrl;

  const ReceiptPreviewDialog({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl.startsWith('data:image')) {
      // Base64 image
      try {
        final base64Content = imageUrl.split(',')[1];
        final bytes = base64Decode(base64Content);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey));
      }
    } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // Remote image url
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
        ),
      );
    } else {
      // Local file path
      final file = File(imageUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(file, fit: BoxFit.contain);
      } else {
        imageWidget = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.grey),
              SizedBox(height: 8),
              Text('ไม่พบไฟล์รูปภาพในเครื่องนี้', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 480,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageWidget,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.6),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => ReceiptPreviewDialog(imageUrl: imageUrl),
    );
  }
}
