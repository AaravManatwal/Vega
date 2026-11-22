import 'dart:async';

/// One incoming transfer waiting for the user's decision on the receiving device.
class ApprovalRequest {
  final String taskId;
  final String senderName;
  final String fileName;
  final int totalBytes;
  final bool encrypted;

  /// True when the sender scanned this device's QR code (identity is proven).
  final bool authenticated;

  /// 6-digit match code; identical on both devices when nobody is in the middle.
  final String sas;

  /// The request is declined automatically at this moment.
  final DateTime expiresAt;

  const ApprovalRequest({
    required this.taskId,
    required this.senderName,
    required this.fileName,
    required this.totalBytes,
    required this.encrypted,
    required this.authenticated,
    required this.sas,
    required this.expiresAt,
  });

  Duration get remaining {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

/// Holds incoming transfers until the user taps Accept or Reject.
///
/// It lives apart from the socket code so the decision logic is small and testable.
/// It is only used once, right after the handshake: chunk streaming never touches it,
/// so it has no effect on transfer speed.
class ApprovalBroker {
  ApprovalBroker({this.timeout = const Duration(seconds: 60)});

  /// How long the user has to decide before the request is declined.
  final Duration timeout;

  /// When false every request is accepted without asking (automation, tests).
  bool requireApproval = true;

  final StreamController<ApprovalRequest> _requests =
      StreamController<ApprovalRequest>.broadcast();
  final StreamController<String> _resolved = StreamController<String>.broadcast();
  final Map<String, Completer<bool>> _pending = {};

  /// New requests for the UI to show.
  Stream<ApprovalRequest> get requests => _requests.stream;

  /// Task ids whose request ended (accepted, rejected, timed out or replaced),
  /// so the UI can close its screen.
  Stream<String> get resolved => _resolved.stream;

  bool get hasPending => _pending.isNotEmpty;

  /// Completes with the user's decision. Declines when nobody is listening,
  /// because an unseen request must never be accepted silently.
  Future<bool> request({
    required String taskId,
    required String senderName,
    required String fileName,
    required int totalBytes,
    required bool encrypted,
    required bool authenticated,
    required String sas,
  }) async {
    if (!requireApproval) return true;
    if (!_requests.hasListener) return false;

    final completer = Completer<bool>();
    final older = _pending[taskId];
    if (older != null && !older.isCompleted) older.complete(false);
    _pending[taskId] = completer;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    _requests.add(
      ApprovalRequest(
        taskId: taskId,
        senderName: senderName,
        fileName: fileName,
        totalBytes: totalBytes,
        encrypted: encrypted,
        authenticated: authenticated,
        sas: sas,
        expiresAt: DateTime.now().add(timeout),
      ),
    );

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      if (identical(_pending[taskId], completer)) {
        _pending.remove(taskId);
      }
      if (!_resolved.isClosed) _resolved.add(taskId);
    }
  }

  /// Called by the UI. Returns false when the request no longer exists.
  bool respond(String taskId, bool accept) {
    final c = _pending[taskId];
    if (c == null || c.isCompleted) return false;
    c.complete(accept);
    return true;
  }

  Future<void> dispose() async {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pending.clear();
    await _requests.close();
    await _resolved.close();
  }
}
