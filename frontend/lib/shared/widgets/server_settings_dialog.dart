import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/websocket/reverb_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Shows the Dispatch Server Connection dialog so standalone APKs can connect
/// over Wi-Fi LAN IP or USB loopback for both REST API and live WebSocket updates.
Future<void> showDriverServerSettingsDialog(BuildContext context, WidgetRef ref) async {
  final storage = ref.read(storageServiceProvider);
  final stored = await storage.getCustomApiUrl();
  if (!context.mounted) return;

  final controller = TextEditingController(
    text: (stored != null && stored.isNotEmpty)
        ? stored
        : (ApiConstants.customFullBaseUrl ?? ApiConstants.defaultBaseUrl),
  );

  bool isTesting = false;
  bool? isHealthy;
  String? statusText;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: AppColors.ambulanceTeal, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dispatch Server Connection',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your dispatch computer IP address when testing across phones on the same Wi-Fi (or keep 127.0.0.1 over USB cable).',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Server Host / LAN IP',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g. 192.168.0.112 or 127.0.0.1',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.ambulanceTeal),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Active API: ${ApiConstants.defaultBaseUrl}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
                if (statusText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: (isHealthy == true ? AppColors.statusGreen : AppColors.emergencyRed)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isHealthy == true ? AppColors.statusGreen : AppColors.emergencyRed)
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isHealthy == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isHealthy == true ? AppColors.statusGreen : AppColors.emergencyRed,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText!,
                            style: TextStyle(
                              color: isHealthy == true ? AppColors.statusGreen : AppColors.emergencyRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      ApiConstants.setServerHost(null);
                      await storage.setCustomApiUrl(null);
                      ref.read(dioClientProvider).refreshBaseUrl();
                      await ref.read(reverbServiceProvider).reconnectIfActive();
                      controller.text = ApiConstants.defaultBaseUrl;
                      setState(() {
                        isHealthy = null;
                        statusText = 'Reset to automatic host (${ApiConstants.displayServerEndpoint}).';
                      });
                    },
              child: const Text(
                'Reset Auto',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setState(() {
                        isTesting = true;
                        statusText = null;
                      });
                      final raw = controller.text.trim();
                      ApiConstants.setServerHost(raw);
                      await storage.setCustomApiUrl(
                        ApiConstants.hasCustomServerHost
                            ? (ApiConstants.customFullBaseUrl ?? raw)
                            : null,
                      );
                      final dio = ref.read(dioClientProvider);
                      dio.refreshBaseUrl();
                      await ref.read(reverbServiceProvider).reconnectIfActive();
                      final ok = await dio.checkHealth();
                      if (!ctx.mounted) return;
                      setState(() {
                        isTesting = false;
                        isHealthy = ok;
                        statusText = ok
                            ? 'Connected to Dispatch Server (${ApiConstants.displayServerEndpoint})'
                            : 'Saved host (${ApiConstants.displayServerEndpoint}), but server did not respond at ${ApiConstants.defaultBaseUrl}.';
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ambulanceTeal,
                foregroundColor: Colors.white,
              ),
              child: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save & Test',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
}

