import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfReportPreviewScreen extends StatelessWidget {
  const PdfReportPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PdfPreview(
        pdfFileName: fileName,
        build: (_) async => bytes,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Tutup',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}