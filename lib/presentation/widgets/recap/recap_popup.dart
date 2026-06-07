import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/services/recap_service.dart';
import '../../../core/constants/app_constants.dart';

// ─── On This Day 팝업 ─────────────────────────────────────────────────────────

class RecapPopup extends StatefulWidget {
  final List<RecapMemory> memories;
  final VoidCallback onClose;

  const RecapPopup({
    super.key,
    required this.memories,
    required this.onClose,
  });

  static Future<void> show(
    BuildContext context,
    List<RecapMemory> memories,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, a1, _) => RecapPopup(
        memories: memories,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionDuration: const Duration(milliseconds: 420),
      transitionBuilder: (ctx, a1, a2, child) {
        final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<RecapPopup> createState() => _RecapPopupState();
}

class _RecapPopupState extends State<RecapPopup> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── 블러 오버레이 ──────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),

          // ── 메인 카드 ──────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFE17055)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset('lib/img/badge/star.svg',
                            width: 14, height: 14,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn)),
                        const SizedBox(width: 6),
                        Text(
                          '추억이 떠올랐어요',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 메모리 카드 PageView
                  SizedBox(
                    height: 380,
                    child: PageView.builder(
                      controller: _ctrl,
                      itemCount: widget.memories.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (ctx, i) =>
                          _MemoryCard(memory: widget.memories[i]),
                    ),
                  ),

                  // 페이지 인디케이터
                  if (widget.memories.length > 1) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.memories.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _page == i ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _page == i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 닫기 버튼
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 메모리 카드 ──────────────────────────────────────────────────────────────

class _MemoryCard extends StatelessWidget {
  final RecapMemory memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    final pin = memory.pin;
    final svgPath = AppConstants.pinShapeSvgs[pin.pinShape] ?? '';
    final shapeName = AppConstants.pinShapeNames[pin.pinShape] ?? pin.pinShape;
    final hasPhoto = pin.photoPaths.isNotEmpty &&
        !pin.photoPaths.first.startsWith('asset:');
    final photoPath = hasPhoto ? pin.photoPaths.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B3A), Color(0xFF0D0B1A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // 배경 글로우
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 연도 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '${memory.yearsAgo}년 전 오늘',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA9EFF),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 사진 or 아이콘
                  if (photoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: photoPath.startsWith('http')
                          ? Image.network(
                              photoPath,
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _CategoryIcon(svgPath: svgPath),
                            )
                          : Image.file(
                              File(photoPath),
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _CategoryIcon(svgPath: svgPath),
                            ),
                    )
                  else
                    _CategoryIcon(svgPath: svgPath),

                  const SizedBox(height: 20),

                  // 날짜
                  Text(
                    _formatDate(pin.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 핀 제목
                  Text(
                    pin.title.isEmpty ? '기록된 장소' : pin.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 카테고리 + 감정
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          shapeName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pin.emotion,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
    return '${dt.year}년 ${months[dt.month - 1]}월 ${dt.day}일';
  }
}

class _CategoryIcon extends StatelessWidget {
  final String svgPath;
  const _CategoryIcon({required this.svgPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.20),
        ),
      ),
      child: Center(
        child: svgPath.isNotEmpty
            ? SvgPicture.asset(
                svgPath,
                width: 48,
                height: 48,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF9B8BFF),
                  BlendMode.srcIn,
                ),
              )
            : const Icon(
                Icons.location_on_rounded,
                size: 48,
                color: Color(0xFF9B8BFF),
              ),
      ),
    );
  }
}

// ─── 위치 기반 배너 ───────────────────────────────────────────────────────────

class RecapLocationBanner extends StatefulWidget {
  final ProximityMemory memory;
  final VoidCallback onDismiss;

  const RecapLocationBanner({
    super.key,
    required this.memory,
    required this.onDismiss,
  });

  @override
  State<RecapLocationBanner> createState() => _RecapLocationBannerState();
}

class _RecapLocationBannerState extends State<RecapLocationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    HapticFeedback.lightImpact();
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
    final pin = widget.memory.pin;
    final svgPath = AppConstants.pinShapeSvgs[pin.pinShape] ?? '';
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasCompanion = pin.companions.isNotEmpty;

    return Positioned(
      bottom: bottomPad + 90,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _dismiss,
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity != null && d.primaryVelocity! > 100) {
                _dismiss();
              }
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1B3A), Color(0xFF0D0B1A)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 아이콘 — 동행자 있으면 사람 아이콘
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: hasCompanion
                          ? const Icon(
                              Icons.people_rounded,
                              size: 24,
                              color: Color(0xFF9B8BFF),
                            )
                          : svgPath.isNotEmpty
                              ? SvgPicture.asset(
                                  svgPath,
                                  width: 24,
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF9B8BFF),
                                    BlendMode.srcIn,
                                  ),
                                )
                              : const Icon(
                                  Icons.location_on_rounded,
                                  size: 24,
                                  color: Color(0xFF9B8BFF),
                                ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.memory.bannerBody,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (pin.title.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            pin.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            maxLines: 1,
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
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
