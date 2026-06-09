import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('[Notification] permission error: $e');
    }
  }

  /// 리캡 "오늘의 추억" 로컬 푸시 알림
  Future<void> showRecapNotification({
    required String pinTitle,
    required int yearsAgo,
    List<String> companions = const [],
  }) async {
    if (!_initialized) return;

    final title = '$yearsAgo년 전 오늘의 추억';
    final body = _buildBody(pinTitle: pinTitle, yearsAgo: yearsAgo, companions: companions);

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
      android: AndroidNotificationDetails(
        'recap_channel',
        '오늘의 추억',
        channelDescription: '과거 방문 장소를 알려드립니다',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.show(1001, title, body, details);
    } catch (e) {
      debugPrint('[Notification] show error: $e');
    }
  }

  String _buildBody({
    required String pinTitle,
    required int yearsAgo,
    required List<String> companions,
  }) {
    final place = pinTitle.isEmpty ? '기록된 장소' : pinTitle;
    if (companions.isEmpty) {
      return '$yearsAgo년 전 오늘 $place을 방문했어요';
    }
    final name = companions.first;
    final extra = companions.length > 1 ? ' 외 ${companions.length - 1}명' : '';
    return '$yearsAgo년 전 $name$extra님과 함께한 $place의 추억이 있어요';
  }
}
