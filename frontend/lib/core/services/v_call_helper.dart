import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/constants.dart';

class VCallHelper {
  /// Opens a Jitsi room in the system browser with robust Linux/Flatpak fallback support.
  static Future<void> openRoom(BuildContext context, String roomId) async {
    final cleanId = roomId.trim().replaceAll('https://meet.jit.si/', '');
    final formattedId = cleanId.startsWith('SMH-') ? cleanId : 'SMH-$cleanId';
    final urlString = 'https://meet.jit.si/$formattedId';
    final uri = Uri.parse(urlString);

    try {
      bool launched = false;

      // Special handling for Linux / Flatpak environments (like Fedora Silverblue)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
        try {
          // Attempt system xdg-open command directly which escapes flatpak restrictions best
          final result = await Process.run('xdg-open', [urlString]);
          if (result.exitCode == 0) {
            launched = true;
          }
        } catch (_) {
          // Fall through to standard launcher if process invocation fails
        }
      }

      if (!launched) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched && context.mounted) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }

      if (!launched && context.mounted) {
        _showManualDialog(context, urlString, formattedId);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening consultation room: $formattedId'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error launching browser: $e');
      if (context.mounted) {
        _showManualDialog(context, urlString, formattedId);
      }
    }
  }

  static void _showManualDialog(BuildContext context, String urlString, String roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Meeting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not open the browser automatically. Use the link below:'),
            const SizedBox(height: 12),
            SelectableText(
              urlString,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}