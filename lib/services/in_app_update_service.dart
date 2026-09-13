import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  InAppUpdateService._();

  /// Checks for Google Play in-app updates and initiates the update flow.
  ///
  /// - [context]: BuildContext to show SnackBars or dialogs.
  /// - [isManualCheck]: If true (e.g. tapped from Settings), provides user
  ///   feedback even when already up to date.
  /// - [forceImmediate]: If true, forces full-screen immediate update flow.
  static Future<void> checkForUpdate({
    required BuildContext context,
    bool isManualCheck = false,
    bool forceImmediate = false,
  }) async {
    // In-app update is only supported on Android native devices
    if (kIsWeb || !Platform.isAndroid) {
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'In-app updates are only available on Android via Google Play.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // 1. Immediate Update Flow (Priority >= 4 or forceImmediate)
        if ((forceImmediate || updateInfo.updatePriority >= 4) &&
            updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
        // 2. Flexible Update Flow (Background download)
        else if (updateInfo.flexibleUpdateAllowed) {
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success && context.mounted) {
            _showUpdateDownloadedSnackBar(context);
          }
        }
        // 3. Fallback to immediate if flexible not allowed
        else if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      } else {
        if (isManualCheck && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are using the latest version!'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[InAppUpdateService] Update check skipped/failed: $e');
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to check for updates right now.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Displays a SnackBar when a flexible update has finished downloading in the
  /// background, allowing the user to restart and apply the update.
  static void _showUpdateDownloadedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Update downloaded and ready to install.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1), // Keep visible until user acts
        action: SnackBarAction(
          label: 'RESTART',
          textColor: Colors.amberAccent,
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('[InAppUpdateService] Error completing update: $e');
            }
          },
        ),
      ),
    );
  }
}
