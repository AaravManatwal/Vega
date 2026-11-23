import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/approval.dart';
import '../../core/security/pairing.dart';
import '../../models/transfer_models.dart';
import '../../screens/approval_screen.dart';
import '../../screens/sender_code_screen.dart';
import '../../screens/transfer_progress_screen.dart';
import '../../services/approval_notifier.dart';
import '../../state/app_state.dart';

/// Sits above the Navigator and opens the right screen when the engine needs the
/// user: Accept? on the receiver, match code on the sender.
class ApprovalHost extends ConsumerStatefulWidget {
  const ApprovalHost({
    super.key,
    required this.navigatorKey,
    required this.messengerKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  @override
  ConsumerState<ApprovalHost> createState() => _ApprovalHostState();
}

class _ApprovalHostState extends ConsumerState<ApprovalHost> {
  final Map<String, Route<void>> _receiverRoutes = {};
  final Map<String, Route<void>> _senderRoutes = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    final engine = ref.read(vegaProvider.notifier).engine;
    _subs.add(engine.approvals.requests.listen(_onRequest));
    _subs.add(engine.approvals.resolved.listen(_onResolved));
    _subs.add(engine.handshakes.listen(_onHandshake));
    _subs.add(engine.taskUpdates.listen(_onTask));
    ApprovalNotifier.instance.onReject = (id) => engine.approvals.respond(id, false);
    ApprovalNotifier.instance.prepare();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  NavigatorState? get _nav => widget.navigatorKey.currentState;

  // ---- Receiver ---------------------------------------------------------------

  void _onRequest(ApprovalRequest req) {
    final nav = _nav;
    if (nav == null) {
      // No screen to show it on: decline rather than accept unseen.
      ref.read(vegaProvider.notifier).engine.approvals.respond(req.taskId, false);
      return;
    }
    final old = _receiverRoutes.remove(req.taskId);
    if (old != null) nav.removeRoute(old);

    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      settings: RouteSettings(name: 'approval:${req.taskId}'),
      builder: (_) => ApprovalScreen(
        request: req,
        window: ref.read(vegaProvider.notifier).engine.approvals.timeout,
        onDecision: (accept) {
          ref.read(vegaProvider.notifier).engine.approvals.respond(req.taskId, accept);
          if (accept) _wantProgress.add(req.taskId);
          _removeReceiver(req.taskId);
        },
      ),
    );
    _receiverRoutes[req.taskId] = route;
    nav.push(route);

    // App not in front: tell the user with a notification as well.
    final life = WidgetsBinding.instance.lifecycleState;
    final alertsOn = ref.read(vegaProvider).settings.alerts;
    if (alertsOn && life != null && life != AppLifecycleState.resumed) {
      ApprovalNotifier.instance.showIncoming(
        taskId: req.taskId,
        senderName: req.senderName,
        fileName: req.fileName,
      );
    }
  }

  void _onResolved(String taskId) => _removeReceiver(taskId);

  void _removeReceiver(String taskId) {
    ApprovalNotifier.instance.clear(taskId);
    final route = _receiverRoutes.remove(taskId);
    final nav = _nav;
    if (route != null && nav != null && route.isActive) nav.removeRoute(route);
  }

  // ---- Sender -----------------------------------------------------------------

  void _onHandshake(HandshakeInfo info) {
    if (!info.outgoing) return; // the receiver's side is handled by _onRequest
    if (_senderRoutes.containsKey(info.taskId)) return;
    final nav = _nav;
    final task = ref.read(vegaProvider).tasks[info.taskId];
    if (nav == null || task == null) return;

    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      settings: RouteSettings(name: 'sender-code:${info.taskId}'),
      builder: (_) => SenderCodeScreen(
        peerName: task.peerName,
        fileName: task.fileName,
        totalBytes: task.totalBytes,
        encrypted: task.encrypted,
        sas: info.sas,
        authenticated: info.authenticated,
        onCancel: () {
          ref.read(vegaProvider.notifier).engine.cancelTransfer(info.taskId);
          _removeSender(info.taskId);
        },
      ),
    );
    _senderRoutes[info.taskId] = route;
    nav.push(route);
  }

  void _onTask(TransferTask task) {
    _maybeOpenProgress(task);
    if (task.direction != TransferDirection.send) return;
    if (!_senderRoutes.containsKey(task.id)) return;
    if (task.status == TransferStatus.connecting || task.status == TransferStatus.queued) {
      return;
    }
    _removeSender(task.id);
    if (task.status == TransferStatus.transferring) {
      _wantProgress.add(task.id);
      _maybeOpenProgress(task);
    }
    if (task.status == TransferStatus.failed || task.status == TransferStatus.cancelled) {
      final msg = task.errorMessage;
      if (msg != null && msg.isNotEmpty) {
        widget.messengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  // ---- Progress ---------------------------------------------------------------

  /// Task ids whose progress screen should open as soon as data starts moving
  /// (the user just approved them, or just passed the code check).
  final Set<String> _wantProgress = {};

  void _maybeOpenProgress(TransferTask task) {
    if (!_wantProgress.contains(task.id)) return;
    if (task.status != TransferStatus.transferring) return;
    final nav = _nav;
    if (nav == null) return;
    _wantProgress.remove(task.id);
    nav.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'progress:${task.id}'),
        builder: (_) => TransferProgressScreen(taskId: task.id),
      ),
    );
  }

  void _removeSender(String taskId) {
    final route = _senderRoutes.remove(taskId);
    final nav = _nav;
    if (route != null && nav != null && route.isActive) nav.removeRoute(route);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
