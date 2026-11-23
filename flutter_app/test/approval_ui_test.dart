import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vega/state/app_state.dart';
import 'package:vega/core/approval.dart';
import 'package:vega/screens/approval_screen.dart';
import 'package:vega/theme/app_theme.dart';

ApprovalRequest _req({bool authenticated = false, bool encrypted = true}) =>
    ApprovalRequest(
      taskId: 't1',
      senderName: 'Rahul',
      fileName: 'Goa_Trip_Video.mp4',
      totalBytes: 1288490188,
      encrypted: encrypted,
      authenticated: authenticated,
      sas: '482913',
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );

Future<void> _show(WidgetTester tester, ApprovalRequest r, void Function(bool) cb) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hindiProvider.overrideWithValue(false)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: ApprovalScreen(request: r, onDecision: cb),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1600));
}

void main() {
  testWidgets('unverified sender: warning, code digits and both buttons', (tester) async {
    await _show(tester, _req(), (_) {});
    expect(find.text('Code matches, Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Not linked by QR'), findsOneWidget);
    for (final d in ['4', '8', '2', '9', '1', '3']) {
      expect(find.text(d), findsWidgets);
    }
  });

  testWidgets('QR verified sender: plain Accept and verified banner', (tester) async {
    await _show(tester, _req(authenticated: true), (_) {});
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Recognised by QR'), findsOneWidget);
  });

  testWidgets('plaintext transfer shows the not-encrypted warning', (tester) async {
    await _show(tester, _req(encrypted: false, authenticated: true), (_) {});
    expect(find.text('This transfer is not encrypted'), findsOneWidget);
  });

  testWidgets('Accept and Reject report the decision', (tester) async {
    bool? got;
    await _show(tester, _req(authenticated: true), (a) => got = a);
    await tester.tap(find.text('Accept'));
    expect(got, isTrue);
    await tester.tap(find.text('Reject'));
    expect(got, isFalse);
  });
}
