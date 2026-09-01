import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:myapp/services/download_notification_service.dart';
import 'package:myapp/services/preferences_service.dart';
import 'package:myapp/utils/l10n_extensions.dart';
import 'package:myapp/widgets/confirm_dialog.dart';

/// Overrides `Platform.isAndroid` for this flow in tests, where the real
/// platform is never Android — the rationale/ask-once logic otherwise
/// couldn't be exercised at all. `null` (the default) means "use the real
/// platform".
@visibleForTesting
bool? isAndroidForTest;

/// Asks for notification permission on the **first** download action, with a
/// localized rationale — not at app startup (BLK-07). A no-op every time
/// after the first, and off Android.
///
/// Call this alongside starting a download; it does not gate or delay the
/// download itself, which proceeds regardless of the answer here.
Future<void> maybeRequestDownloadNotificationPermission(
  BuildContext context,
) async {
  if (!(isAndroidForTest ?? Platform.isAndroid)) return;
  if (PreferencesService.instance.hasAskedDownloadNotificationPermission) {
    return;
  }
  await PreferencesService.instance
      .saveHasAskedDownloadNotificationPermission();
  if (!context.mounted) return;

  final l10n = context.l10n;
  final allowed = await showConfirmDialog(
    context,
    title: l10n.downloadNotificationRationaleTitle,
    message: l10n.downloadNotificationRationaleMessage,
    confirmLabel: l10n.downloadNotificationRationaleAllow,
    cancelLabel: l10n.cancel,
  );
  if (!allowed) return;

  await DownloadNotificationService.instance.requestPermission();
}
