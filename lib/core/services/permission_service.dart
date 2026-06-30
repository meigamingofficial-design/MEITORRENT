import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';

/// Centralized service for handling storage permissions.
///
/// On Android 13+ (SDK 33+) scoped storage requires no permission for
/// app-specific dirs. On Android 10–12 we request READ/WRITE_EXTERNAL_STORAGE.
/// MANAGE_EXTERNAL_STORAGE is NOT used — it violates Google Play policy for
/// download/torrent apps.
class PermissionService {
  PermissionService._();

  /// Shows the premium rationale dialog for "All files access".
  /// Returns true if the user tapped "Grant Access", false if "Skip for now".
  static Future<bool> showStorageRationale(BuildContext context) async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surface(ctx),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.downloading.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.downloading,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Storage Access Required',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  color: AppColors.text(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              // Body
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Meitorrent needs storage permission to:',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(ctx),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• Save torrent downloads\n'
                '• Resume downloads after restart\n'
                '• Remove downloaded files',
                textAlign: TextAlign.left,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(ctx),
                  fontSize: 13,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Storage permission is needed to save and manage files in your selected download folder.\n\n'
                'On the next screen, allow storage access for Meitorrent.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(ctx),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Privacy reassurance
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.downloading.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.downloading.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.downloading,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Meitorrent only accesses files related to your downloads. Your personal data is never collected or shared.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.downloading,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.border(ctx)),
                      ),
                      child: Text(
                        'Skip for now',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary(ctx),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.downloading,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Grant Access',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return granted ?? false;
  }

  /// Check if the app has the storage access it needs for the current Android version.
  ///
  /// Android version breakdown:
  /// - API 29+ (Android 10+): Apps can write to getExternalFilesDir() with NO permission.
  ///   No permission dialog ever needed. Returns true immediately.
  /// - API 28 and below (Android 9-): Needs READ/WRITE_EXTERNAL_STORAGE.
  static Future<bool> isStorageGranted() async {
    final sdkInt = await _getSdkInt();
    // Android 10+ (API 29+): scoped storage — no permission needed for app dirs
    if (sdkInt >= 29) return true;
    // Android 9 and below: need legacy storage permission
    return await Permission.storage.isGranted;
  }

  static Future<int> _getSdkInt() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 33; // safe fallback — assume modern Android, no permission needed
    }
  }
}
