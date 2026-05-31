import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/widgets/confirm_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) onOpenDialog,
  }) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: Center(
              child: FilledButton(
                onPressed: () => onOpenDialog(context),
                child: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cancel dismisses dialog and keeps parent go_router route',
      (tester) async {
    await pumpHost(
      tester,
      onOpenDialog: (context) async {
        await showConfirmDialog(
          context,
          title: 'Clear all downloads?',
          message: 'Files will be deleted.',
          confirmLabel: 'Delete all',
          destructive: true,
        );
      },
    );

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Open dialog'), findsOneWidget);
  });

  testWidgets('confirm returns true without popping parent route', (tester) async {
    var confirmed = false;

    await pumpHost(
      tester,
      onOpenDialog: (context) async {
        confirmed = await showConfirmDialog(
          context,
          title: 'Delete download?',
          message: 'Remove offline file.',
          confirmLabel: 'Delete',
        );
      },
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('filled confirm button works for non-destructive actions',
      (tester) async {
    var confirmed = false;

    await pumpHost(
      tester,
      onOpenDialog: (context) async {
        confirmed = await showConfirmDialog(
          context,
          title: 'Restart Class 01?',
          message: 'Restart from the first part?',
          confirmLabel: 'Restart',
          filledConfirm: true,
        );
      },
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('Settings'), findsOneWidget);
  });
}
