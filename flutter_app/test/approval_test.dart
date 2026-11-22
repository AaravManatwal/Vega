import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vega/core/approval.dart';

Future<bool> _ask(ApprovalBroker b, {String id = 't1'}) => b.request(
      taskId: id,
      senderName: 'Rahul',
      fileName: 'a.mp4',
      totalBytes: 10,
      encrypted: true,
      authenticated: false,
      sas: '482913',
    );

void main() {
  group('ApprovalBroker', () {
    test('accepts when the user taps Accept', () async {
      final b = ApprovalBroker();
      final sub = b.requests.listen((r) => b.respond(r.taskId, true));
      expect(await _ask(b), isTrue);
      await sub.cancel();
      await b.dispose();
    });

    test('rejects when the user taps Reject', () async {
      final b = ApprovalBroker();
      final sub = b.requests.listen((r) => b.respond(r.taskId, false));
      expect(await _ask(b), isFalse);
      await sub.cancel();
      await b.dispose();
    });

    test('declines on timeout', () async {
      final b = ApprovalBroker(timeout: const Duration(milliseconds: 50));
      final sub = b.requests.listen((_) {});
      expect(await _ask(b), isFalse);
      await sub.cancel();
      await b.dispose();
    });

    test('declines when nobody is listening (never accepts unseen)', () async {
      final b = ApprovalBroker();
      expect(await _ask(b), isFalse);
      await b.dispose();
    });

    test('requireApproval=false accepts without asking', () async {
      final b = ApprovalBroker()..requireApproval = false;
      expect(await _ask(b), isTrue);
      await b.dispose();
    });

    test('request carries the match code and an expiry', () async {
      final b = ApprovalBroker(timeout: const Duration(seconds: 5));
      final got = Completer<ApprovalRequest>();
      final sub = b.requests.listen((r) {
        got.complete(r);
        b.respond(r.taskId, true);
      });
      await _ask(b);
      final r = await got.future;
      expect(r.sas, '482913');
      expect(r.senderName, 'Rahul');
      expect(r.remaining.inSeconds, inInclusiveRange(3, 5));
      await sub.cancel();
      await b.dispose();
    });

    test('resolved stream reports the task id', () async {
      final b = ApprovalBroker();
      final sub = b.requests.listen((r) => b.respond(r.taskId, true));
      final resolved = b.resolved.first;
      await _ask(b, id: 'zz');
      expect(await resolved, 'zz');
      await sub.cancel();
      await b.dispose();
    });

    test('a newer request for the same task replaces the older one', () async {
      final b = ApprovalBroker();
      int seen = 0;
      late final Future<bool> first;
      final sub = b.requests.listen((r) {
        seen++;
        if (seen == 2) b.respond(r.taskId, true);
      });
      first = _ask(b);
      final second = _ask(b);
      expect(await first, isFalse);
      expect(await second, isTrue);
      await sub.cancel();
      await b.dispose();
    });

    test('respond returns false for an unknown task', () async {
      final b = ApprovalBroker();
      expect(b.respond('nope', true), isFalse);
      await b.dispose();
    });
  });
}
