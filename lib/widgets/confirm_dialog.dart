import 'package:flutter/material.dart';

/// Shows a single-action informational dialog. Uses the dialog's [BuildContext]
/// for the pop so it works correctly under go_router.
Future<void> showAlertDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? okLabel,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            okLabel ?? MaterialLocalizations.of(dialogContext).okButtonLabel,
          ),
        ),
      ],
    ),
  );
}

/// Shows a two-action confirmation dialog and returns whether the user confirmed.
///
/// Always pops using the dialog's [BuildContext], not the caller's. Using the
/// caller context with [Navigator.pop] under go_router pops the route instead
/// of the dialog and can empty the navigation stack.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  required String confirmLabel,
  bool destructive = false,
  bool filledConfirm = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final confirmStyle =
          destructive ? TextStyle(color: theme.colorScheme.error) : null;

      Widget confirmButton;
      if (filledConfirm) {
        confirmButton = FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        );
      } else {
        confirmButton = TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel, style: confirmStyle),
        );
      }

      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          confirmButton,
        ],
      );
    },
  );
  return result ?? false;
}
