import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/providers/donghaeng_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../application/providers/pin_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../data/models/pin_model.dart';
import '../common/glass_sheet.dart';
import 'pin_create_sheet.dart';

class PinDetailSheet extends ConsumerWidget {
  final String pinId;
  final VoidCallback onClose;
  final PinModel? overridePin;
  final bool readOnly;

  const PinDetailSheet({
    super.key,
    required this.pinId,
    required this.onClose,
    this.overridePin,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PinModel? pin;
    if (overridePin != null) {
      pin = overridePin;
    } else {
      final pins = ref.watch(pinsProvider);
      pin = pins.where((p) => p.id == pinId).firstOrNull;
    }

    if (pin == null) return const SizedBox.shrink();
    // Reassign to non-nullable for closure capture
    final PinModel p = pin;

    return GlassSheet(
      centered: true,
      alignment: const Alignment(0, 0.55),
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 사진 갤러리 (최상단) ────────────────────────────────────────────
          if (pin.photoPaths.isNotEmpty) ...[
            _PhotoGallery(paths: pin.photoPaths),
            const SizedBox(height: 14),
          ],

          // 제목
          Text(
            pin.title,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: context.labelColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // 뱃지 (감정 + 날씨 + 공개범위)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Badge(
                  label: pin.emotion,
                  color: context.primaryColor,
                  textColor: context.primaryColor.computeLuminance() > 0.35
                      ? const Color(0xFF1A1A1A)
                      : Colors.white),
              _Badge(label: _weatherLabel(pin.weather), svgPath: _weatherSvg(pin.weather)),
              _Badge(label: _visibilityLabel(pin.visibility), svgPath: _visibilitySvg(pin.visibility)),
            ],
          ),
          const SizedBox(height: 8),

          // 날짜
          Text(
            DateFormat('yyyy년 M월 d일').format(pin.createdAt),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.grey),
          ),
          const SizedBox(height: 4),

          // 주소
          _AddressLine(lat: pin.latitude, lng: pin.longitude),
          const SizedBox(height: 10),

          // 감정 강도
          Row(
            children: [
              const Text('감정 강도 ',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey)),
              ...List.generate(
                  5,
                  (i) => Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (i + 1) <= p.intensityLevel
                              ? context.primaryColor
                              : context.emptyStateBg,
                        ),
                      )),
            ],
          ),
          const SizedBox(height: 10),

          // 동행자
          if (pin.companions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                const Text('함께 ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey)),
                Expanded(
                  child: Text(
                    pin.companions.join(', '),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 설명
          if (pin.description.isNotEmpty) ...[
            Text(
              pin.description,
              style: TextStyle(
                  fontSize: 14,
                  color: context.labelColor,
                  height: 1.6,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
          ],

          // ── 동행 버튼 (태그된 친구 있고 내 핀인 경우) ─────────────────────
          if (!readOnly && p.taggedFriendCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DonghaengButton(pin: p, onClose: onClose),
          ],

          // 액션 버튼 (공유는 항상, 편집/삭제는 내 핀만)
          const Divider(height: 20),
          Row(
            children: [
              if (!readOnly)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _openEditSheet(context, ref, p),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('편집',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.greyLight),
                  ),
                ),
              Expanded(child: _ShareButton(pin: p)),
              if (!readOnly)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      ref.read(pinsProvider.notifier).remove(p.id);
                      onClose();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('삭제',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref, PinModel pin) {
    showAppSheet<void>(
      context,
      builder: (_) => PinCreateSheet(
        location: LatLng(pin.latitude, pin.longitude),
        editPin: pin,
        onClose: () => Navigator.of(context).pop(),
        onSaved: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─── 역지오코딩 주소 ───────────────────────────────────────────────────────────

class _AddressLine extends StatefulWidget {
  final double lat;
  final double lng;
  const _AddressLine({required this.lat, required this.lng});

  @override
  State<_AddressLine> createState() => _AddressLineState();
}

class _AddressLineState extends State<_AddressLine> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final placemarks =
          await placemarkFromCoordinates(widget.lat, widget.lng);
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [p.administrativeArea, p.subLocality, p.locality]
          .where((s) => s != null && s.isNotEmpty)
          .toSet()
          .toList();
      if (mounted && parts.isNotEmpty) {
        setState(() => _address = parts.take(2).join(' '));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_address == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.grey),
        const SizedBox(width: 3),
        Text(_address!,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.grey,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── 사진 갤러리 (시트 상단, 탭 → 전체화면 뷰어) ──────────────────────────────

class _PhotoGallery extends StatefulWidget {
  final List<String> paths;
  const _PhotoGallery({required this.paths});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _currentIndex = 0;

  void _openViewer(BuildContext context, int startIndex) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (ctx, a1, a2) => _PhotoViewerPage(
          paths: widget.paths,
          initialIndex: startIndex,
        ),
        transitionsBuilder: (ctx, anim, a2, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paths.length == 1) {
      return GestureDetector(
        onTap: () => _openViewer(context, 0),
        child: _buildThumb(widget.paths.first, 0),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _openViewer(context, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildThumb(widget.paths[i], i),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.paths.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == _currentIndex ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == _currentIndex
                    ? context.labelColor
                    : context.countBadgeBg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumb(String path, int index) {
    final isAsset = path.startsWith('asset:');
    final isUrl = path.startsWith('http');
    final image = isAsset
        ? Image.asset(
            path.substring(6),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (ctx, e, s) => _brokenImage(),
          )
        : isUrl
            ? Image.network(
                path,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, s) => _brokenImage(),
              )
            : Image.file(
                File(path),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, s) => _brokenImage(),
              );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: image,
        ),
        // 탭 힌트 (확대 아이콘)
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fullscreen_rounded,
                size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _brokenImage() => Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.greyLight, size: 32),
      );
}

// ─── 전체화면 이미지 뷰어 ─────────────────────────────────────────────────────

class _PhotoViewerPage extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _PhotoViewerPage({
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 이미지 PageView (핀치 줌) ────────────────────────────────────
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.paths.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) =>
                  _ZoomablePhoto(path: widget.paths[i]),
            ),

            // ── 상단 바 ──────────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                current: _currentIndex + 1,
                total: widget.paths.length,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),

            // ── 플로팅 반응 오버레이 (이미지 영역에만 국한) ─────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              bottom: MediaQuery.of(context).padding.bottom + 36,
              left: 0,
              right: 0,
              child: ClipRect(child: const _ReactionsOverlay()),
            ),

            // ── 하단 인디케이터 ──────────────────────────────────────────────
            if (widget.paths.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.paths.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _currentIndex ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _currentIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 핀치 줌 가능한 사진 ──────────────────────────────────────────────────────

class _ZoomablePhoto extends StatefulWidget {
  final String path;
  const _ZoomablePhoto({required this.path});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (_transformCtrl.value != Matrix4.identity()) {
      _transformCtrl.value = Matrix4.identity();
    } else {
      // 2배 확대 (중앙)
      _transformCtrl.value = Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAsset = widget.path.startsWith('asset:');
    final isUrl = widget.path.startsWith('http');
    final image = isAsset
        ? Image.asset(
            widget.path.substring(6),
            fit: BoxFit.contain,
            errorBuilder: (ctx, e, s) => const _BrokenPhoto(),
          )
        : isUrl
            ? Image.network(
                widget.path,
                fit: BoxFit.contain,
                errorBuilder: (ctx, e, s) => const _BrokenPhoto(),
              )
            : Image.file(
                File(widget.path),
                fit: BoxFit.contain,
                errorBuilder: (ctx, e, s) => const _BrokenPhoto(),
              );

    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformCtrl,
        minScale: 0.8,
        maxScale: 5.0,
        clipBehavior: Clip.none,
        child: Center(child: image),
      ),
    );
  }
}

class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.white38, size: 48),
      );
}

// ─── 상단 바 ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onClose;

  const _TopBar({
    required this.current,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.60),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
          const Spacer(),
          if (total > 1)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$current / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 플로팅 반응 오버레이 (인스타 스토리 / TV플 스타일) ──────────────────────

const _kDemoReactions = [
  ('lib/img/emotion/heart-svgrepo-com.svg', null),
  ('lib/img/ui/bolt-svgrepo-com.svg', null),
  ('lib/img/emotion/hand-heart.svg', null),
  ('lib/img/emotion/like-svgrepo-com.svg', null),
  ('lib/img/badge/star.svg', null),
  (null, '여기 진짜 좋다'),
  (null, '오 어디야?'),
  (null, '나도 가고싶다!'),
  (null, '대박이다 ㅋㅋ'),
  (null, '분위기 미쳤다'),
  (null, '같이 가자'),
  (null, '사진 잘 찍었다'),
];

class _ReactionsOverlay extends StatefulWidget {
  const _ReactionsOverlay();

  @override
  State<_ReactionsOverlay> createState() => _ReactionsOverlayState();
}

class _ReactionsOverlayState extends State<_ReactionsOverlay>
    with TickerProviderStateMixin {
  final _rng = math.Random();
  final List<_ReactionItem> _items = [];

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    if (!mounted) return;
    final delay = 1200 + _rng.nextInt(2000); // 1.2~3.2초 간격
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _spawnReaction();
      _scheduleNext();
    });
  }

  void _spawnReaction() {
    final pick = _kDemoReactions[_rng.nextInt(_kDemoReactions.length)];
    final ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2800 + _rng.nextInt(600)),
    );
    final drift = (_rng.nextDouble() - 0.5) * 24; // -12 ~ +12 px 좌우 흔들림

    final item = _ReactionItem(
      emoji: pick.$1,
      text: pick.$2,
      xFrac: 0.55 + _rng.nextDouble() * 0.36, // 오른쪽 55~91% 영역
      xDrift: drift,
      ctrl: ctrl,
    );

    ctrl.forward().then((_) {
      if (!mounted) return;
      setState(() => _items.remove(item));
      ctrl.dispose();
    });

    setState(() => _items.add(item));
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return IgnorePointer(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: _items.map((item) {
              // 이미지 영역 하단 80%에서 출발 → 상단 10%까지 이동
              final startY = h * 0.80;
              final travel = h * 0.72;

              return AnimatedBuilder(
                animation: item.ctrl,
                builder: (ctx, child) {
                  final t = item.ctrl.value;
                  final ease = Curves.easeOut.transform(t);
                  final y = startY - ease * travel;
                  // x 드리프트: ease-in-out으로 자연스럽게 흔들림
                  final x = item.xFrac * w + item.xDrift * ease;
                  // 페이드: 처음 15% fade-in, 마지막 20% fade-out
                  final opacity = t < 0.15
                      ? t / 0.15
                      : t > 0.80
                          ? (1.0 - t) / 0.20
                          : 1.0;

                  return Positioned(
                    left: (x - 40).clamp(8.0, w - 120.0),
                    top: y,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: item.emoji != null
                          ? _FloatingEmoji(svgPath: item.emoji!)
                          : _FloatingComment(text: item.text!),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ReactionItem {
  final String? emoji;
  final String? text;
  final double xFrac;
  final double xDrift; // 위로 올라가며 좌우로 흘러가는 량 (px)
  final AnimationController ctrl;

  const _ReactionItem({
    required this.emoji,
    required this.text,
    required this.xFrac,
    required this.xDrift,
    required this.ctrl,
  });
}

class _FloatingEmoji extends StatelessWidget {
  final String svgPath;
  const _FloatingEmoji({required this.svgPath});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      svgPath,
      width: 28,
      height: 28,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

class _FloatingComment extends StatelessWidget {
  final String text;
  const _FloatingComment({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

// ─── 날씨 / 공개범위 SVG 매핑 ────────────────────────────────────────────────

String? _weatherSvg(String weather) {
  if (weather.contains('맑음')) return 'lib/img/nature/sun.svg';
  if (weather.contains('비')) return 'lib/img/nature/cloud-rain.svg';
  if (weather.contains('흐림')) return 'lib/img/nature/cloud-sun-rain.svg';
  if (weather.contains('눈')) return 'lib/img/nature/cloud-snow.svg';
  if (weather.contains('바람')) return 'lib/img/wind-svgrepo-com.svg';
  return null;
}

String _weatherLabel(String weather) {
  if (weather.contains('맑음')) return '맑음';
  if (weather.contains('비')) return '비';
  if (weather.contains('흐림')) return '흐림';
  if (weather.contains('눈')) return '눈';
  if (weather.contains('바람')) return '바람';
  return weather;
}

String? _visibilitySvg(String visibility) {
  if (visibility.contains('전체')) return 'lib/img/ui/layout-grid.svg';
  if (visibility.contains('친구')) return 'lib/img/ui/profile-circle-svgrepo-com.svg';
  if (visibility.contains('나만')) return 'lib/img/ui/security-protection-lock-padlock-round-locked-svgrepo-com.svg';
  return null;
}

String _visibilityLabel(String visibility) {
  if (visibility.contains('전체')) return '전체 공개';
  if (visibility.contains('친구')) return '친구 공개';
  if (visibility.contains('나만')) return '나만 보기';
  return visibility;
}

// ─── 배지 ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final String? svgPath;

  const _Badge({required this.label, this.color, this.textColor, this.svgPath});

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.greyLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? context.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? context.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (svgPath != null) ...[
            SvgPicture.asset(
              svgPath!,
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg),
          ),
        ],
      ),
    );
  }
}

// ─── 공유 버튼 ────────────────────────────────────────────────────────────────

class _ShareButton extends StatefulWidget {
  final PinModel pin;
  const _ShareButton({required this.pin});

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _sharing = false;
  final _cardKey = GlobalKey();

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.mediumImpact();

    try {
      final overlayState = Overlay.of(context);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -9999,
          top: 0,
          width: 360,
          child: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(
              key: _cardKey,
              child: _ShareCard(pin: widget.pin),
            ),
          ),
        ),
      );
      overlayState.insert(entry);
      await Future.delayed(const Duration(milliseconds: 200));

      Uint8List? pngBytes;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        pngBytes = byteData?.buffer.asUint8List();
      }
      entry.remove();

      if (pngBytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/pinlog_share_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        if (!mounted) return;
        await Share.shareXFiles([XFile(file.path)], text: widget.pin.title);
      }
    } catch (_) {}

    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _sharing ? null : _share,
      icon: _sharing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_rounded, size: 16),
      label: const Text('공유', style: TextStyle(fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(foregroundColor: AppColors.greyLight),
    );
  }
}

// ─── 공유 카드 (오프스크린 렌더링용) ──────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  final PinModel pin;
  const _ShareCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 앱 브랜드
          Row(
            children: [
              const Text(
                'Pinlog',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white38,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Icon(
                AppEmotions.iconOf(pin.emotion),
                size: 20,
                color: Colors.white60,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 제목
          Text(
            pin.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),

          // 설명
          if (pin.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              pin.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.55,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // 날짜 + 감정 뱃지
          Row(
            children: [
              _ShareBadge(
                '${pin.createdAt.year}. ${pin.createdAt.month}. ${pin.createdAt.day}',
              ),
              const SizedBox(width: 8),
              _ShareBadge(pin.emotion),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 동행 버튼 ────────────────────────────────────────────────────────────────

class _DonghaengButton extends ConsumerWidget {
  final PinModel pin;
  final VoidCallback onClose;

  const _DonghaengButton({required this.pin, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dongState = ref.watch(donghaengProvider);
    final isActiveForThisPin =
        dongState.isActive && dongState.session?.pinId == pin.id;
    final otherSessionActive =
        dongState.isActive && dongState.session?.pinId != pin.id;
    final themeColor = context.primaryColor;

    if (otherSessionActive) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (isActiveForThisPin) {
          HapticFeedback.lightImpact();
          ref.read(donghaengProvider.notifier).endSession();
          onClose();
          return;
        }
        HapticFeedback.mediumImpact();
        final profile = ref.read(profileProvider);
        ref.read(donghaengProvider.notifier).startSession(
          pin,
          profile.nickname,
        );
        onClose();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: isActiveForThisPin
              ? null
              : LinearGradient(
                  colors: [
                    themeColor.withValues(alpha: 0.85),
                    themeColor,
                  ],
                ),
          color: isActiveForThisPin
              ? themeColor.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(14),
          border: isActiveForThisPin
              ? Border.all(color: themeColor.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActiveForThisPin
                  ? Icons.location_on_rounded
                  : Icons.share_location_rounded,
              size: 16,
              color: isActiveForThisPin ? themeColor : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              isActiveForThisPin ? '동행 진행 중 (종료)' : '동행 시작',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActiveForThisPin ? themeColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareBadge extends StatelessWidget {
  final String text;
  const _ShareBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }
}
