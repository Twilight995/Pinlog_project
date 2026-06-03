import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';
import '../../../data/repositories/shared_map_repository.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _sharedMapRepoProvider = Provider((_) => SharedMapRepository());

final _sharedPinsProvider =
    FutureProvider.autoDispose<List<SharedPinEntry>>((ref) async {
  final friends = ref.watch(friendsProvider);
  final friendUids = friends
      .map((f) => f.supabaseUid)
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .toList();
  final uidToNickname = <String, String>{
    for (final f in friends)
      if (f.supabaseUid != null && f.supabaseUid!.isNotEmpty)
        f.supabaseUid!: f.name,
  };
  final repo = ref.read(_sharedMapRepoProvider);
  final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final friendPins = await repo.fetchFriendPins(friendUids, uidToNickname);
  final myPins = myUid.isNotEmpty
      ? await repo.fetchMyPublicPins(myUid)
      : <SharedPinEntry>[];
  return [...myPins, ...friendPins];
});

// ─── 색상 헬퍼 ────────────────────────────────────────────────────────────────

Color _colorForUid(String uid) {
  const colors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];
  return colors[uid.codeUnitAt(0) % colors.length];
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SharedMapScreen extends ConsumerStatefulWidget {
  const SharedMapScreen({super.key});

  @override
  ConsumerState<SharedMapScreen> createState() => _SharedMapScreenState();
}

class _SharedMapScreenState extends ConsumerState<SharedMapScreen> {
  final _mapController = MapController();
  String? _filterUid;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _showPinDetail(PinModel pin, String ownerUid) {
    final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.30),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) => PinDetailSheet(
        pinId: pin.id,
        overridePin: pin,
        readOnly: ownerUid != myUid,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx2, anim, a2, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final pinsAsync = ref.watch(_sharedPinsProvider);
    final themeColor = context.primaryColor;
    final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final topPad = MediaQuery.of(context).padding.top;
    final isDark = context.isDark;

    final tileUrl = isDark
        ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF0F0F0),
      body: Stack(
        children: [
          // ── 지도 (순수 Flutter — PlatformView 없음) ────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(36.5, 127.5),
              initialZoom: 5.5,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              // OSM 타일 레이어
              TileLayer(
                urlTemplate: tileUrl,
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.pinlog.app',
              ),
              // 핀 마커 레이어
              pinsAsync.when(
                data: (entries) {
                  final filtered = _filterUid == null
                      ? entries
                      : entries.where((e) => e.ownerUid == _filterUid).toList();
                  return MarkerLayer(
                    markers: filtered.map((e) {
                      final isMine = e.ownerUid == myUid;
                      final color = isMine ? themeColor : _colorForUid(e.ownerUid);
                      final initial = e.ownerNickname.isNotEmpty
                          ? e.ownerNickname[0]
                          : '?';
                      return Marker(
                        point: LatLng(e.pin.latitude, e.pin.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showPinDetail(e.pin, e.ownerUid),
                          child: _PinMarker(
                            color: color,
                            initial: initial,
                            isMine: isMine,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const MarkerLayer(markers: []),
                error: (e, st) => const MarkerLayer(markers: []),
              ),
            ],
          ),

          // ── 상단 헤더 ────────────────────────────────────────────────
          Positioned(
            top: topPad.clamp(0.0, 62.0) + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.cardBg.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: context.labelColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.cardBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        '공유 지도',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.labelColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (friends.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _FriendFilterChips(
                    friends: friends,
                    selectedUid: _filterUid,
                    onSelect: (uid) {
                      HapticFeedback.selectionClick();
                      setState(() => _filterUid = uid);
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── 로딩 ──────────────────────────────────────────────────────
          if (pinsAsync.isLoading)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.cardBg.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('친구 핀 불러오는 중...',
                          style: TextStyle(
                              fontSize: 13, color: context.labelColor)),
                    ],
                  ),
                ),
              ),
            ),

          // ── 빈 상태 ──────────────────────────────────────────────────
          pinsAsync.maybeWhen(
            data: (entries) {
              final filtered = _filterUid == null
                  ? entries
                  : entries.where((e) => e.ownerUid == _filterUid).toList();
              return filtered.isEmpty
                  ? Positioned(
                      bottom: 140,
                      left: 24,
                      right: 24,
                      child: _EmptyState(hasFriends: friends.isNotEmpty),
                    )
                  : const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // ── 범례 ──────────────────────────────────────────────────────
          pinsAsync.maybeWhen(
            data: (entries) => entries.isNotEmpty
                ? Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 16,
                    right: 16,
                    child: _Legend(entries: entries, myUid: myUid),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── 마커 위젯 ────────────────────────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  final Color color;
  final String initial;
  final bool isMine;

  const _PinMarker({
    required this.color,
    required this.initial,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          isMine ? '나' : initial,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─── 친구 필터 칩 ─────────────────────────────────────────────────────────────

class _FriendFilterChips extends StatelessWidget {
  final List<Friend> friends;
  final String? selectedUid;
  final ValueChanged<String?> onSelect;

  const _FriendFilterChips({
    required this.friends,
    required this.selectedUid,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: '전체',
            selected: selectedUid == null,
            onTap: () => onSelect(null),
          ),
          ...friends
              .where((f) =>
                  f.supabaseUid != null && f.supabaseUid!.isNotEmpty)
              .map((f) => _Chip(
                    label: f.name,
                    selected: selectedUid == f.supabaseUid,
                    onTap: () => onSelect(f.supabaseUid),
                  )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? context.primaryColor
              : context.cardBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? context.primaryColor : context.glassBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.labelColor,
          ),
        ),
      ),
    );
  }
}

// ─── 범례 ─────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final List<SharedPinEntry> entries;
  final String myUid;

  const _Legend({required this.entries, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final owners = <String, String>{};
    for (final e in entries) {
      owners[e.ownerUid] = e.ownerNickname;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
        ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: owners.entries.map((e) {
          final isMine = e.key == myUid;
          final color = isMine ? context.primaryColor : _colorForUid(e.key);
          final pinCount = entries.where((p) => p.ownerUid == e.key).length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                '${isMine ? "나" : e.value} ($pinCount)',
                style: TextStyle(fontSize: 11, color: context.labelColor),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── 빈 상태 ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFriends;
  const _EmptyState({required this.hasFriends});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFriends
                ? Icons.place_outlined
                : Icons.people_outline_rounded,
            size: 36,
            color: context.subLabelColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            hasFriends ? '공유된 핀이 없어요' : '아직 친구가 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.labelColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFriends
                ? '친구가 공개 또는 친구 공개로 핀을 남기면\n이 지도에 표시돼요'
                : '프로필 → 설정 → 친구 관리에서\n친구를 추가해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.subLabelColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
