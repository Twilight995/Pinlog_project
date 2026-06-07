import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meeting.dart';

class MeetingRepository {
  final SupabaseClient _db = Supabase.instance.client;

  RealtimeChannel? _channel;
  final _friendLocationCtrl = StreamController<(double, double)>.broadcast();

  Stream<(double, double)> get friendLocationStream =>
      _friendLocationCtrl.stream;

  String get _myUid => _db.auth.currentUser?.id ?? '';

  // ── Supabase CRUD ─────────────────────────────────────────────────────────

  Future<Meeting?> getActiveMeeting() async {
    final uid = _myUid;
    if (uid.isEmpty) return null;
    try {
      final rows = await _db
          .from('scheduled_meetings')
          .select()
          .or('meet_uid.eq.$uid,invitee_uid.eq.$uid')
          .not('status', 'eq', 'completed')
          .order('scheduled_at')
          .limit(1);
      if (rows.isEmpty) return null;
      final meeting = Meeting.fromJson(rows.first);

      // Fetch friend profile
      final friendUid =
          meeting.meetUid == uid ? meeting.inviteeUid : meeting.meetUid;
      final userRows = await _db
          .from('users')
          .select('nickname,avatar_url')
          .eq('uid', friendUid)
          .limit(1);
      if (userRows.isNotEmpty) {
        final u = userRows.first;
        return meeting.copyWith(
          friendNickname: u['nickname'] as String?,
          friendAvatarUrl: u['avatar_url'] as String?,
        );
      }
      return meeting;
    } catch (_) {
      return null;
    }
  }

  Future<Meeting?> createMeeting({
    required String inviteeUid,
    required double targetLat,
    required double targetLng,
    String? targetName,
    required DateTime scheduledAt,
    TransitMode transitMode = TransitMode.transit,
  }) async {
    final uid = _myUid;
    if (uid.isEmpty) return null;
    try {
      final rows = await _db.from('scheduled_meetings').insert({
        'meet_uid': uid,
        'invitee_uid': inviteeUid,
        'target_lat': targetLat,
        'target_lng': targetLng,
        'target_name': ?targetName,
        'scheduled_at': scheduledAt.toIso8601String(),
        'transit_mode': transitMode.name,
        'status': 'upcoming',
      }).select();
      if (rows.isEmpty) return null;
      return Meeting.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateStatus(String id, MeetingStatus status) async {
    try {
      await _db.from('scheduled_meetings').update({
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
  }

  Future<List<Meeting>> getAllMeetings() async {
    final uid = _myUid;
    if (uid.isEmpty) return [];
    try {
      final rows = await _db
          .from('scheduled_meetings')
          .select()
          .or('meet_uid.eq.$uid,invitee_uid.eq.$uid')
          .order('scheduled_at', ascending: false);
      if (rows.isEmpty) return [];

      final meetings = rows.map((r) => Meeting.fromJson(r)).toList();

      // Batch-fetch unique friend UIDs
      final friendUids = meetings
          .map((m) => m.meetUid == uid ? m.inviteeUid : m.meetUid)
          .toSet()
          .toList();
      final userRows = await _db
          .from('users')
          .select('uid,nickname,avatar_url')
          .inFilter('uid', friendUids);
      final userMap = {
        for (final u in userRows) u['uid'] as String: u,
      };

      return meetings.map((m) {
        final friendUid = m.meetUid == uid ? m.inviteeUid : m.meetUid;
        final u = userMap[friendUid];
        if (u == null) return m;
        return m.copyWith(
          friendNickname: u['nickname'] as String?,
          friendAvatarUrl: u['avatar_url'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateTransitMode(String id, TransitMode mode) async {
    try {
      await _db.from('scheduled_meetings').update({
        'transit_mode': mode.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
  }

  // ── Realtime Presence (live location) ─────────────────────────────────────

  Future<void> joinLocationChannel(String meetingId) async {
    _channel?.unsubscribe();
    _channel = _db.channel('meeting:$meetingId');

    _channel!.onPresenceSync((_) {
      final states = _channel!.presenceState();
      final uid = _myUid;
      for (final state in states) {
        for (final p in state.presences) {
          final payload = p.payload;
          if (payload['uid'] != uid) {
            final lat = (payload['lat'] as num?)?.toDouble();
            final lng = (payload['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _friendLocationCtrl.add((lat, lng));
            }
          }
        }
      }
    });

    _channel!.subscribe();
  }

  Future<void> broadcastLocation(double lat, double lng) async {
    await _channel?.track({'uid': _myUid, 'lat': lat, 'lng': lng});
  }

  Future<void> leaveLocationChannel() async {
    await _channel?.untrack();
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    leaveLocationChannel().ignore();
    _friendLocationCtrl.close();
  }
}
