import 'dart:math' as math;

class DonghaengParticipant {
  final String uid;
  final String nickname;
  final double? lat;
  final double? lng;
  final bool arrivedHome;
  final DateTime? lastSeen;

  const DonghaengParticipant({
    required this.uid,
    required this.nickname,
    this.lat,
    this.lng,
    this.arrivedHome = false,
    this.lastSeen,
  });

  DonghaengParticipant copyWith({
    double? lat,
    double? lng,
    bool? arrivedHome,
    DateTime? lastSeen,
  }) =>
      DonghaengParticipant(
        uid: uid,
        nickname: nickname,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        arrivedHome: arrivedHome ?? this.arrivedHome,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  double? distanceTo(double myLat, double myLng) {
    if (lat == null || lng == null) return null;
    const R = 6371000.0;
    final dLat = _rad(lat! - myLat);
    final dLon = _rad(lng! - myLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(myLat)) *
            math.cos(_rad(lat!)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

class DonghaengSession {
  final String pinId;
  final String pinTitle;
  final List<DonghaengParticipant> participants;
  final DateTime startedAt;

  const DonghaengSession({
    required this.pinId,
    required this.pinTitle,
    required this.participants,
    required this.startedAt,
  });

  DonghaengSession copyWith({List<DonghaengParticipant>? participants}) =>
      DonghaengSession(
        pinId: pinId,
        pinTitle: pinTitle,
        participants: participants ?? this.participants,
        startedAt: startedAt,
      );
}
