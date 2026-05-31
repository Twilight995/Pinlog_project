import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings, Size;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/shared_map_repository.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _sharedMapRepoProvider = Provider((_) => SharedMapRepository());

final _sharedPinsProvider =
    FutureProvider.autoDispose.family<List<SharedPinEntry>, List<String>>(
        (ref, friendUids) async {
  final repo = ref.read(_sharedMapRepoProvider);
  final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final friendPins = await repo.fetchFriendPins(friendUids);
  final myPins = myUid.isNotEmpty ? await repo.fetchMyPublicPins(myUid) : <SharedPinEntry>[];
  return [...myPins, ...friendPins];
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class SharedMapScreen extends ConsumerStatefulWidget {
  const SharedMapScreen({super.key});

  @override
  ConsumerState<SharedMapScreen> createState() => _SharedMapScreenState();
}

class _SharedMapScreenState extends ConsumerState<SharedMapScreen> {
  PointAnnotationManager? _pinManager;
  Cancelable? _tapSub;
  bool _mapReady = false;

  // 선택된 친구 필터 (null = 전체)
  String? _filterUid;

  // 마커 탭 → 핀 ID 매핑
  final Map<String, String> _annotationToPinId = {};

  @override
  void dispose() {
    _tapSub?.cancel();
    _pinManager?.deleteAll().ignore();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _pinManager = await map.annotations.createPointAnnotationManager();
    _tapSub = _pinManager!.tapEvents(
      onTap: (annotation) {
        final pinId = _annotationToPinId[annotation.id];
        if (pinId != null) _showPinDetail(pinId);
      },
    );
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    if (mounted) setState(() => _mapReady = true);
  }

  void _showPinDetail(String pinId) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.30),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) => PinDetailSheet(
        pinId: pinId,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx2, anim, a2, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  Future<void> _renderPins(List<SharedPinEntry> entries, Color themeColor) async {
    if (!_mapReady || _pinManager == null) return;
    await _pinManager!.deleteAll();
    _annotationToPinId.clear();

    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    final filtered = _filterUid == null
        ? entries
        : entries.where((e) => e.ownerUid == _filterUid).toList();

    if (filtered.isEmpty) return;

    final images = await Future.wait(
      filtered.map((e) => _buildSharedMarker(e, themeColor, pixelRatio)),
    );

    final options = List.generate(
      filtered.length,
      (i) => PointAnnotationOptions(
        geometry: Point(
            coordinates: Position(filtered[i].pin.longitude, filtered[i].pin.latitude)),
        image: images[i],
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
      ),
    );

    final created = await _pinManager!.createMulti(options);
    for (var i = 0; i < created.length; i++) {
      final ann = created[i];
      if (ann == null) continue;
      _annotationToPinId[ann.id] = filtered[i].pin.id;
    }
  }

  // ─── 마커 비트맵: 친구 아바타 초성 원형 마커 ──────────────────────────────
  Future<Uint8List> _buildSharedMarker(
    SharedPinEntry entry,
    Color themeColor,
    double pixelRatio,
  ) async {
    final isMine = entry.ownerUid == (Supabase.instance.client.auth.currentUser?.id ?? '');
    const logicalSize = 48.0;
    final pxSize = (logicalSize * pixelRatio).roundToDouble();
    final cx = pxSize / 2;
    final cy = pxSize / 2;
    final r = pxSize / 2 - pixelRatio * 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));

    final color = isMine ? themeColor : _friendColor(entry.ownerUid);

    // 글로우
    canvas.drawCircle(Offset(cx, cy), r + pixelRatio * 2,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 5));

    // 원형 배경
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pixelRatio * 2
          ..color = color);

    // 초성 텍스트
    final initial = (entry.ownerNickname.isNotEmpty ? entry.ownerNickname[0] : '?');
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: r * 0.72,
        fontWeight: FontWeight.bold,
      ),
    )..pushStyle(ui.TextStyle(color: color, fontWeight: FontWeight.w800))
      ..addText(initial);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: pxSize));
    canvas.drawParagraph(para, Offset(0, cy - para.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  Color _friendColor(String uid) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];
    return colors[uid.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final friendUids = friends.map((f) => f.firestoreUid ?? '').where((u) => u.isNotEmpty).toList();
    final pinsAsync = ref.watch(_sharedPinsProvider(friendUids));
    final themeColor = context.primaryColor;
    final topPad = MediaQuery.of(context).padding.top;

    // 핀 목록이 로드되면 지도에 렌더링
    ref.listen(_sharedPinsProvider(friendUids), (prev, next) {
      next.whenData((entries) => _renderPins(entries, themeColor));
    });

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // ── 지도 ──────────────────────────────────────────────────────────
          Positioned.fill(
            child: MapWidget(
              styleUri: context.isDark
                  ? 'mapbox://styles/mapbox/dark-v11'
                  : 'mapbox://styles/mapbox/light-v11',
              onMapCreated: _onMapCreated,
            ),
          ),

          // ── 상단 헤더 ──────────────────────────────────────────────────────
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뒤로가기 + 제목
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.cardBg.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.cardBg.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
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
                const SizedBox(height: 10),
                // 친구 필터 칩
                if (friends.isNotEmpty)
                  _FriendFilterChips(
                    friends: friends,
                    selectedUid: _filterUid,
                    onSelect: (uid) {
                      HapticFeedback.selectionClick();
                      setState(() => _filterUid = uid);
                      pinsAsync.whenData((entries) => _renderPins(entries, themeColor));
                    },
                  ),
              ],
            ),
          ),

          // ── 로딩 인디케이터 ────────────────────────────────────────────────
          if (pinsAsync.isLoading)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.cardBg.withValues(alpha: 0.92),
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
                          style: TextStyle(fontSize: 13, color: context.labelColor)),
                    ],
                  ),
                ),
              ),
            ),

          // ── 빈 상태 ──────────────────────────────────────────────────────
          if (pinsAsync.hasValue && !pinsAsync.isLoading)
            pinsAsync.when(
              data: (entries) => entries.isEmpty
                  ? Positioned(
                      bottom: 140,
                      left: 24,
                      right: 24,
                      child: _EmptyState(hasFriends: friends.isNotEmpty),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),

          // ── 범례 ──────────────────────────────────────────────────────────
          pinsAsync.when(
            data: (entries) => entries.isNotEmpty
                ? Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 16,
                    right: 16,
                    child: _Legend(entries: entries, myUid: Supabase.instance.client.auth.currentUser?.id ?? ''),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (err, st) => const SizedBox.shrink(),
          ),
        ],
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
          ...friends.map((f) => _Chip(
                label: f.name,
                selected: selectedUid == f.firestoreUid,
                onTap: () => onSelect(f.firestoreUid),
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
              : context.cardBg.withValues(alpha: 0.92),
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
        color: context.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
        ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: owners.entries.map((e) {
          final isMine = e.key == myUid;
          final color = isMine
              ? context.primaryColor
              : _colorFor(e.key);
          final pinCount = entries.where((p) => p.ownerUid == e.key).length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('${isMine ? "나" : e.value} ($pinCount)',
                  style: TextStyle(fontSize: 11, color: context.labelColor)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _colorFor(String uid) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];
    return colors[uid.codeUnitAt(0) % colors.length];
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
        color: context.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFriends ? Icons.place_outlined : Icons.people_outline_rounded,
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

