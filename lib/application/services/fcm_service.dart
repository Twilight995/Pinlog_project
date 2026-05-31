import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/nav_provider.dart';
import '../../main.dart';

const _kFcmEnabledKey = 'fcm_enabled';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] background: ${message.notification?.title}');
}

class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      _setEnabled(false);
      return;
    }

    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    await _uploadToken();
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _uploadToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('users').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', uid);
    } catch (_) {}
  }

  // ── 포그라운드 인앱 배너 ────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;
    _showInAppBanner(title: title ?? '', body: body ?? '', data: message.data);
  }

  void _showInAppBanner({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final nav = pinlogNavigatorKey.currentState;
    if (nav == null) return;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _FcmBanner(
        title: title,
        body: body,
        onTap: () {
          entry?.remove();
          _navigate(data);
        },
        onDismiss: () => entry?.remove(),
      ),
    );
    nav.overlay?.insert(entry);

    // 4초 뒤 자동 제거
    Timer(const Duration(seconds: 4), () {
      if (entry?.mounted ?? false) entry?.remove();
    });
  }

  // ── 알림 탭 → 화면 이동 ───────────────────────────────────────────────────

  void _handleTap(RemoteMessage message) {
    _navigate(message.data);
  }

  void _navigate(Map<String, dynamic> data) {
    final nav = pinlogNavigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'] as String?;
    switch (type) {
      case 'meeting':
        // 지도 탭(0)으로 이동 — 약속 오버레이가 거기 있음
        _switchTab(0);
      case 'friend_request':
      case 'friend':
        _switchTab(3); // 프로필 → 친구 진입
      case 'pin':
        _switchTab(0);
      default:
        // 타입 없으면 지도 탭으로
        _switchTab(0);
    }
  }

  void _switchTab(int index) {
    final context = pinlogNavigatorKey.currentContext;
    if (context == null) return;
    try {
      ProviderScope.containerOf(context)
          .read(activeTabProvider.notifier)
          .state = index;
    } catch (_) {}
  }

  // ── 설정 ──────────────────────────────────────────────────────────────────

  Future<void> setEnabled(bool enabled) async {
    _setEnabled(enabled);
    if (enabled) {
      await _uploadToken();
    } else {
      await _messaging.deleteToken();
    }
  }

  bool get isEnabled =>
      Hive.box<dynamic>('settings').get(_kFcmEnabledKey, defaultValue: true) as bool;

  void _setEnabled(bool v) =>
      Hive.box<dynamic>('settings').put(_kFcmEnabledKey, v);
}

// ─── 인앱 배너 위젯 ──────────────────────────────────────────────────────────

class _FcmBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FcmBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FcmBanner> createState() => _FcmBannerState();
}

class _FcmBannerState extends State<_FcmBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragEnd: (d) {
                if (d.primaryVelocity != null && d.primaryVelocity! < -100) {
                  _dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFF6C5CE7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title.isNotEmpty)
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (widget.body.isNotEmpty) ...[
                            if (widget.title.isNotEmpty)
                              const SizedBox(height: 2),
                            Text(
                              widget.body,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
