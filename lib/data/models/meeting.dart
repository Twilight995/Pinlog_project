enum TransitMode { driving, transit, walking }

enum MeetingStatus { upcoming, approaching, meeting, completed }

class Meeting {
  final String id;
  final String meetUid;
  final String inviteeUid;
  final double targetLat;
  final double targetLng;
  final String? targetName;
  final DateTime scheduledAt;
  final TransitMode transitMode;
  final MeetingStatus status;

  // Live ephemeral fields (not persisted)
  final String? friendNickname;
  final String? friendAvatarUrl;

  const Meeting({
    required this.id,
    required this.meetUid,
    required this.inviteeUid,
    required this.targetLat,
    required this.targetLng,
    this.targetName,
    required this.scheduledAt,
    this.transitMode = TransitMode.transit,
    this.status = MeetingStatus.upcoming,
    this.friendNickname,
    this.friendAvatarUrl,
  });

  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
        id: j['id'] as String,
        meetUid: j['meet_uid'] as String,
        inviteeUid: j['invitee_uid'] as String,
        targetLat: (j['target_lat'] as num).toDouble(),
        targetLng: (j['target_lng'] as num).toDouble(),
        targetName: j['target_name'] as String?,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        transitMode: TransitMode.values.firstWhere(
          (e) => e.name == (j['transit_mode'] as String? ?? 'transit'),
          orElse: () => TransitMode.transit,
        ),
        status: MeetingStatus.values.firstWhere(
          (e) => e.name == (j['status'] as String? ?? 'upcoming'),
          orElse: () => MeetingStatus.upcoming,
        ),
      );

  Map<String, dynamic> toJson() => {
        'meet_uid': meetUid,
        'invitee_uid': inviteeUid,
        'target_lat': targetLat,
        'target_lng': targetLng,
        if (targetName != null) 'target_name': targetName,
        'scheduled_at': scheduledAt.toIso8601String(),
        'transit_mode': transitMode.name,
        'status': status.name,
      };

  Meeting copyWith({
    TransitMode? transitMode,
    MeetingStatus? status,
    String? friendNickname,
    String? friendAvatarUrl,
  }) =>
      Meeting(
        id: id,
        meetUid: meetUid,
        inviteeUid: inviteeUid,
        targetLat: targetLat,
        targetLng: targetLng,
        targetName: targetName,
        scheduledAt: scheduledAt,
        transitMode: transitMode ?? this.transitMode,
        status: status ?? this.status,
        friendNickname: friendNickname ?? this.friendNickname,
        friendAvatarUrl: friendAvatarUrl ?? this.friendAvatarUrl,
      );

  String get transitSvgPath {
    return switch (transitMode) {
      TransitMode.driving => 'lib/img/car-svgrepo-com.svg',
      TransitMode.transit => 'lib/img/bus-svgrepo-com.svg',
      TransitMode.walking => 'lib/img/walk-svgrepo-com.svg',
    };
  }
}
