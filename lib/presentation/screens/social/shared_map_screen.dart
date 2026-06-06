import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide Size;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/providers/pin_provider.dart'
    show mapStyleProvider, MapStyleOption;
import '../../../application/providers/theme_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';
import '../../../data/repositories/shared_map_repository.dart';
import '../../widgets/map/pin_detail_sheet.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _sharedMapRepoProvider = Provider((_) => SharedMapRepository());

final _sharedPinsProvider =
    FutureProvider.autoDispose<List<SharedPinEntry>>((ref) async {
  final friends = ref.watch(friendsProvider);

  final realFriendUids = friends
      .map((f) => f.supabaseUid)
      .whereType<String>()
      .where((u) => u.isNotEmpty && !u.startsWith('demo_'))
      .toList();
  final uidToNickname = <String, String>{
    for (final f in friends)
      if (f.supabaseUid != null && f.supabaseUid!.isNotEmpty)
        f.supabaseUid!: f.name,
  };
  final repo = ref.read(_sharedMapRepoProvider);
  final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final friendPins = await repo.fetchFriendPins(realFriendUids, uidToNickname);
  final myPins = myUid.isNotEmpty
      ? await repo.fetchMyPublicPins(myUid)
      : <SharedPinEntry>[];

  final hasDemoFriends =
      friends.any((f) => f.supabaseUid?.startsWith('demo_') == true);
  final demoPins = hasDemoFriends ? buildDemoPins() : <SharedPinEntry>[];

  return [...myPins, ...friendPins, ...demoPins];
});

// ─── 색상 헬퍼 ────────────────────────────────────────────────────────────────

// 데모 친구는 고정 색 → 최대 대비
const _kDemoColors = {
  'demo_jihu_001': Color(0xFFEF4444),    // 선명한 빨강
  'demo_seoyeon_002': Color(0xFF06B6D4), // 선명한 하늘
};

Color _colorForUid(String uid) {
  if (_kDemoColors.containsKey(uid)) return _kDemoColors[uid]!;
  const colors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];
  if (uid.isEmpty) return colors[0];
  return colors[uid.codeUnitAt(0) % colors.length];
}

// ─── 핀 비트맵 생성 (메인 지도와 동일 디자인) ─────────────────────────────────

final _bitmapCache = <String, Uint8List>{};

// 공유 지도 핀 바디: 원색 그대로 — 화이트 아이콘 가독성을 위해 약간만 어둡게
Color _sharedPinBodyColor(Color theme) {
  final hsl = HSLColor.fromColor(theme);
  final targetL = (hsl.lightness * 0.80).clamp(0.35, 0.55);
  return hsl
      .withLightness(targetL)
      .withSaturation(hsl.saturation.clamp(0.75, 1.0))
      .toColor()
      .withValues(alpha: 0.97);
}

List<Color> _pinBorderGradient(Color theme) {
  return [
    Color.lerp(theme, Colors.white, 0.65)!,
    theme,
  ];
}

Future<Uint8List> _buildSharedPinBitmap({
  required Color themeColor,
  required String svgPath,
  required double pixelRatio,
}) async {
  final key =
      'shared_${themeColor.toARGB32()}_${svgPath}_${pixelRatio.toStringAsFixed(1)}';
  if (_bitmapCache.containsKey(key)) return _bitmapCache[key]!;

  const logicalSize = 80.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pixelRatio * 17.0;
  final gradientRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

  final bodyColor = _sharedPinBodyColor(themeColor);
  final borderColors = _pinBorderGradient(themeColor);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));
  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, pxSize, pxSize)));

  // 글로우
  canvas.drawCircle(
    Offset(cx, cy),
    r + pixelRatio * 3,
    Paint()
      ..color = themeColor.withValues(alpha: 0.28)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 7),
  );
  // 드롭 섀도우
  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 2.5),
    r,
    Paint()
      ..color = const Color(0x50000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 5),
  );
  // 핀 바디
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bodyColor);
  // 그라디언트 테두리
  final borderW = 2.4 * pixelRatio;
  canvas.drawCircle(
    Offset(cx, cy),
    r - borderW / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderW
      ..shader = LinearGradient(
        colors: borderColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(gradientRect),
  );
  // 하이라이트
  canvas.drawOval(
    Rect.fromLTWH(cx - r * 0.38, cy - r * 0.82, r * 0.76, r * 0.38),
    Paint()..color = const Color(0x18FFFFFF),
  );

  // SVG 아이콘
  if (svgPath.isNotEmpty) {
    try {
      final loader = SvgAssetLoader(svgPath);
      final info = await vg.loadPicture(loader, null);
      final iconPx = r * 1.08;
      final scale = iconPx / math.max(info.size.width, info.size.height);
      final scaledW = info.size.width * scale;
      final scaledH = info.size.height * scale;
      final ox = cx - scaledW / 2;
      final oy = cy - scaledH / 2;
      canvas.saveLayer(
        Rect.fromLTWH(ox, oy, scaledW, scaledH),
        Paint()..color = Colors.white,
      );
      canvas.save();
      canvas.translate(ox, oy);
      canvas.scale(scale);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, info.size.width, info.size.height),
        Paint()
          ..colorFilter =
              const ui.ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      canvas.drawPicture(info.picture);
      canvas.restore();
      canvas.restore();
      canvas.restore();
      info.picture.dispose();
    } catch (_) {}
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  _bitmapCache[key] = bytes;
  return bytes;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SharedMapScreen extends ConsumerStatefulWidget {
  const SharedMapScreen({super.key});

  @override
  ConsumerState<SharedMapScreen> createState() => _SharedMapScreenState();
}

class _SharedMapScreenState extends ConsumerState<SharedMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pinManager;
  bool _mapReady = false;
  bool _isUpdating = false;

  String? _filterUid;
  double _pixelRatio = 3.0;

  // annotation id → SharedPinEntry
  final Map<String, SharedPinEntry> _annotationToEntry = {};

  List<SharedPinEntry> _lastEntries = [];

  @override
  void dispose() {
    _bitmapCache.clear();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.location
        .updateSettings(LocationComponentSettings(enabled: false));
    await mapboxMap.compass
        .updateSettings(CompassSettings(enabled: false));

    _pinManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    _pinManager!.tapEvents(
      onTap: (annotation) {
        final entry = _annotationToEntry[annotation.id];
        if (entry == null) return;
        HapticFeedback.lightImpact();
        _showPinDetail(entry.pin, entry.ownerUid);
      },
    );

    setState(() => _mapReady = true);

    // 현재 핀이 이미 로드돼 있으면 바로 마커 그리기
    if (_lastEntries.isNotEmpty) {
      await _updateMarkers(_lastEntries);
    }
  }

  Future<void> _updateMarkers(List<SharedPinEntry> entries) async {
    if (_mapboxMap == null || _pinManager == null || _isUpdating) return;
    _isUpdating = true;

    try {
      await _pinManager!.deleteAll();
      _annotationToEntry.clear();

      final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final themeColor = ref.read(themePresetProvider).primary;
      final pixelRatio = _pixelRatio;

      final toCreate = <PointAnnotationOptions>[];
      final entryList = <SharedPinEntry>[];

      for (final e in entries) {
        final isMine = e.ownerUid == myUid;
        final color = isMine ? themeColor : _colorForUid(e.ownerUid);
        final svgPath =
            AppConstants.pinShapeSvgs[e.pin.pinShape] ?? '';

        final bytes = await _buildSharedPinBitmap(
          themeColor: color,
          svgPath: svgPath,
          pixelRatio: pixelRatio,
        );

        toCreate.add(PointAnnotationOptions(
          geometry: Point(
              coordinates: Position(e.pin.longitude, e.pin.latitude)),
          image: bytes,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ));
        entryList.add(e);
      }

      if (toCreate.isEmpty) return;
      final created = await _pinManager!.createMulti(toCreate);
      for (var i = 0; i < created.length; i++) {
        final id = created[i]?.id;
        if (id != null) _annotationToEntry[id] = entryList[i];
      }
    } finally {
      _isUpdating = false;
    }
  }

  void _showPinDetail(PinModel pin, String ownerUid) {
    final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.30),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, a1, a2) => PinDetailSheet(
        pinId: pin.id,
        overridePin: pin,
        readOnly: ownerUid != myUid,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx2, anim, a2, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
  }

  /// 현재 필터 적용된 entries 반환
  List<SharedPinEntry> _filtered(List<SharedPinEntry> all) {
    if (_filterUid == null) return all;
    return all.where((e) => e.ownerUid == _filterUid).toList();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final pinsAsync = ref.watch(_sharedPinsProvider);
    final themeColor = context.primaryColor;
    final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final topPad = MediaQuery.of(context).padding.top;
    _pixelRatio = View.of(context).devicePixelRatio;
    final currentStyle = ref.watch(mapStyleProvider);
    final isDark = currentStyle == MapStyleOption.dark ||
        (currentStyle == MapStyleOption.auto &&
            Theme.of(context).brightness == Brightness.dark);
    final styleUri = isDark ? MapboxStyles.DARK : MapboxStyles.STANDARD;

    // 핀 로드 완료 시 마커 업데이트
    pinsAsync.whenData((entries) {
      final filtered = _filtered(entries);
      if (_mapReady &&
          filtered.map((e) => e.pin.id).join() !=
              _lastEntries.map((e) => e.pin.id).join()) {
        _lastEntries = filtered;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateMarkers(filtered);
        });
      }
    });

    // 필터 변경 시 재그리기
    pinsAsync.whenData((entries) {
      final filtered = _filtered(entries);
      _lastEntries = filtered;
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050B1A),
      body: Stack(
        children: [
          // ── Mapbox 지도 ─────────────────────────────────────────────────
          MapWidget(
            styleUri: styleUri,
            viewport: CameraViewportState(
              center: Point(coordinates: Position(126.978, 37.5665)),
              zoom: 11.0,
              pitch: 0,
              bearing: 0,
            ),
            onMapCreated: _onMapCreated,
          ),

          // ── 상단 헤더 ────────────────────────────────────────────────────
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
                    myUid: myUid,
                    selectedUid: _filterUid,
                    onSelect: (uid) {
                      HapticFeedback.selectionClick();
                      setState(() => _filterUid = uid);
                      // 필터 변경 → 마커 재렌더
                      pinsAsync.whenData((entries) {
                        _lastEntries = [];
                        _updateMarkers(_filtered(entries));
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── 로딩 ────────────────────────────────────────────────────────
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

          // ── 빈 상태 ──────────────────────────────────────────────────────
          pinsAsync.maybeWhen(
            data: (entries) {
              final filtered = _filtered(entries);
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

          // ── 범례 ────────────────────────────────────────────────────────
          pinsAsync.maybeWhen(
            data: (entries) => entries.isNotEmpty
                ? Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 16,
                    right: 16,
                    child: _Legend(
                        entries: entries,
                        myUid: myUid,
                        themeColor: themeColor),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── 친구 필터 칩 ─────────────────────────────────────────────────────────────

class _FriendFilterChips extends StatelessWidget {
  final List<Friend> friends;
  final String myUid;
  final String? selectedUid;
  final ValueChanged<String?> onSelect;

  const _FriendFilterChips({
    required this.friends,
    required this.myUid,
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
            color: context.primaryColor,
            onTap: () => onSelect(null),
          ),
          // 나
          _Chip(
            label: '나',
            selected: selectedUid == myUid,
            color: context.primaryColor,
            onTap: () => onSelect(myUid),
          ),
          ...friends
              .where((f) => f.supabaseUid != null && f.supabaseUid!.isNotEmpty)
              .map((f) => _Chip(
                    label: f.name,
                    selected: selectedUid == f.supabaseUid,
                    color: _colorForUid(f.supabaseUid!),
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
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : context.cardBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color : context.glassBorder,
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
  final Color themeColor;

  const _Legend(
      {required this.entries, required this.myUid, required this.themeColor});

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
          final color = isMine ? themeColor : _colorForUid(e.key);
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
              Text(
                '${isMine ? "나" : e.value} ($pinCount)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.labelColor,
                ),
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
