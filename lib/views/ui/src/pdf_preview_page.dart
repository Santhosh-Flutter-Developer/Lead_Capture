import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '/models/models.dart';
import '/utils/utils.dart';

/// In-app PDF viewer for an already-uploaded attachment (native platforms
/// only — on the web, attachments are opened in a new browser tab instead).
class PdfPreviewPage extends StatelessWidget {
  final FileModel file;
  const PdfPreviewPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          file.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.document_download),
            tooltip: 'Download',
            onPressed: () =>
                Download.downloadFromUrl(context, file.url, file.name),
          ),
        ],
      ),
      body: SfPdfViewer.network(
        file.url,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
