import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Heads-up notification for "someone wants to send you a file" while Vega is in the
/// background. Tapping it opens the app on the Accept screen, where the 6-digit code
/// is checked — so there is deliberately no Accept button on the notification itself.
/// "Reject" is offered as a quick action.
class ApprovalNotifier {
  ApprovalNotifier._();
  static final ApprovalNotifier instance = ApprovalNotifier._();

  static const String _channelId = 'vega_incoming';
  static const String _rejectAction = 'reject';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called with the task id when the user taps Reject on the notification.
  void Function(String taskId)? onReject;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;

  Future<void> prepare() async {
    if (!_supported || _ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Notifications are a convenience; the in-app screen still works without them.
    }
  }

  void _onResponse(NotificationResponse r) {
    final id = r.payload;
    if (id == null || id.isEmpty) return;
    if (r.actionId == _rejectAction) onReject?.call(id);
  }

  Future<void> showIncoming({
    required String taskId,
    required String senderName,
    required String fileName,
  }) async {
    if (!_supported) return;
    if (!_ready) await prepare();
    if (!_ready) return;
    try {
      await _plugin.show(
        _idFor(taskId),
        '$senderName file bhejna chahta hai',
        '$fileName — dekhne ke liye tap kijiye',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Aane wali files',
            channelDescription: 'Jab koi aapko file bhejna chahe, tab yahan batata hai.',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.private,
            timeoutAfter: 60000,
            autoCancel: true,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                _rejectAction,
                'Mana karein',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        payload: taskId,
      );
    } catch (_) {}
  }

  Future<void> clear(String taskId) async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancel(_idFor(taskId));
    } catch (_) {}
  }
}
