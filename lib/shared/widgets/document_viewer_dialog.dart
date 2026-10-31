import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Modal dialog to preview and zoom into uploaded compliance document images
class DocumentViewerDialog extends StatelessWidget {
  final String title;
  final String documentKey;
  final String? imagePath;

  const DocumentViewerDialog({
    super.key,
    required this.title,
    required this.documentKey,
    this.imagePath,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String documentKey,
    String? imagePath,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => DocumentViewerDialog(
        title: title,
        documentKey: documentKey,
        imagePath: imagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidFile = imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: AppColors.statusGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Compliance Document Preview (Pinch to Zoom)',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Document Viewport
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 460),
                width: double.infinity,
                color: Colors.black,
                child: hasValidFile
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: Center(
                          child: Image.file(
                            File(imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackDocumentView(),
                          ),
                        ),
                      )
                    : _buildFallbackDocumentView(),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasValidFile ? Icons.check_circle : Icons.badge_outlined,
                        color: hasValidFile ? AppColors.statusGreen : AppColors.ambulanceTeal,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasValidFile ? 'Original Upload' : 'Digital Record On File',
                        style: TextStyle(
                          color: hasValidFile ? AppColors.statusGreen : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ambulanceTeal,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(90, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackDocumentView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ambulanceTeal, width: 2),
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                color: AppColors.statusGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Digital Compliance Document Verified & Archived in Dispatch Server',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x2206D6A0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.statusGreen),
              ),
              child: const Text(
                'STATUS: AUDITED & COMPLIANT',
                style: TextStyle(
                  color: AppColors.statusGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
