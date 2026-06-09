import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/services/recap_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

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
    final isDark = context.isDark;
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.25);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── 블러 오버레이 ──────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: overlayColor),
              ),
            ),
          ),

          // ── 메인 카드 ──────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더 배지
                  _HeaderBadge(isDark: isDark, primaryColor: context.primaryColor),
                  const SizedBox(height: 14),

                  // 메모리 카드 PageView
                  SizedBox(
                    height: 420,
                    child: PageView.builder(
                      controller: _ctrl,
                      itemCount: widget.memories.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (ctx, i) => _MemoryCard(
                        memory: widget.memories[i],
                        isDark: isDark,
                        primaryColor: context.primaryColor,
                      ),
                    ),
                  ),

                  // 페이지 인디케이터
                  if (widget.memories.length > 1) ...[
                    const SizedBox(height: 12),
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
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 닫기 버튼
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
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

// ── 헤더 배지 ─────────────────────────────────────────────────────────────────

class _HeaderBadge extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;
  const _HeaderBadge({required this.isDark, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFFE17055)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          SizedBox(width: 6),
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
    );
  }
}

// ─── 메모리 카드 ──────────────────────────────────────────────────────────────

class _MemoryCard extends StatelessWidget {
  final RecapMemory memory;
  final bool isDark;
  final Color primaryColor;
  const _MemoryCard({
    required this.memory,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final pin = memory.pin;
    final svgPath = AppConstants.pinShapeSvgs[pin.pinShape] ?? '';
    final emotionSvg = AppConstants.emotionSvgPath(pin.emotion);
    final shapeName = AppConstants.pinShapeNames[pin.pinShape] ?? pin.pinShape;

    // http URL 우선, 없으면 asset:, 없으면 로컬 파일 경로
    final photoPath = pin.photoPaths.isNotEmpty ? pin.photoPaths.first : '';
    final hasPhoto = photoPath.isNotEmpty;

    final cardBg = isDark ? const Color(0xFF141414) : Colors.white;
    final labelColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final subColor = isDark ? const Color(0xFF888888) : const Color(0xFF6B6B6B);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF2F2F7);
    final chipTextColor = isDark ? const Color(0xFFCCCCCC) : const Color(0xFF444444);
    final badgeBg = isDark
        ? primaryColor.withValues(alpha: 0.22)
        : primaryColor.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 히어로 이미지 / 플레이스홀더 ──────────────────────────
            _HeroSection(
              hasPhoto: hasPhoto,
              photoPath: photoPath,
              svgPath: svgPath,
              yearsAgo: memory.yearsAgo,
              primaryColor: primaryColor,
              isDark: isDark,
            ),

            // ── 콘텐츠 ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜
                    Text(
                      _formatDate(pin.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // 핀 제목
                    Text(
                      pin.title.isEmpty ? '기록된 장소' : pin.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 설명 (있을 때만)
                    if (pin.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        pin.description,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: subColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),

                    // 태그 행
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // 감정 태그
                        if (pin.emotion.isNotEmpty)
                          _Chip(
                            iconWidget: emotionSvg != null
                                ? SvgPicture.asset(
                                    emotionSvg,
                                    width: 12,
                                    height: 12,
                                    colorFilter: ColorFilter.mode(
                                        chipTextColor, BlendMode.srcIn),
                                  )
                                : null,
                            label: pin.emotion,
                            bg: chipBg,
                            textColor: chipTextColor,
                          ),
                        // 날씨 태그
                        if (pin.weather.isNotEmpty)
                          _Chip(
                            label: pin.weather,
                            bg: chipBg,
                            textColor: chipTextColor,
                          ),
                        // 카테고리 태그
                        if (shapeName.isNotEmpty)
                          _Chip(
                            iconWidget: svgPath.isNotEmpty
                                ? SvgPicture.asset(
                                    svgPath,
                                    width: 12,
                                    height: 12,
                                    colorFilter: ColorFilter.mode(
                                        primaryColor, BlendMode.srcIn),
                                  )
                                : null,
                            label: shapeName,
                            bg: badgeBg,
                            textColor: primaryColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '1', '2', '3', '4', '5', '6',
      '7', '8', '9', '10', '11', '12',
    ];
    return '${dt.year}년 ${months[dt.month - 1]}월 ${dt.day}일';
  }
}

// ── 히어로 섹션 ───────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final bool hasPhoto;
  final String photoPath;
  final String svgPath;
  final int yearsAgo;
  final Color primaryColor;
  final bool isDark;

  const _HeroSection({
    required this.hasPhoto,
    required this.photoPath,
    required this.svgPath,
    required this.yearsAgo,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경: 사진 or 그라디언트
          if (hasPhoto)
            _buildPhoto()
          else
            _buildGradientPlaceholder(),

          // 하단 페이드 (카드 배경색으로)
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 60,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      (isDark ? const Color(0xFF141414) : Colors.white)
                          .withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // "N년 전 오늘" 배지
          Positioned(
            top: 14,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Text(
                '$yearsAgo년 전 오늘',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    if (photoPath.startsWith('asset:')) {
      return Image.asset(
        photoPath.substring(6),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildGradientPlaceholder(),
      );
    }
    if (photoPath.startsWith('http')) {
      return Image.network(
        photoPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildGradientPlaceholder(),
      );
    }
    return Image.file(
      File(photoPath),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _buildGradientPlaceholder(),
    );
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.25),
            primaryColor.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: svgPath.isNotEmpty
            ? SvgPicture.asset(
                svgPath,
                width: 56,
                height: 56,
                colorFilter: ColorFilter.mode(
                  primaryColor.withValues(alpha: 0.60),
                  BlendMode.srcIn,
                ),
              )
            : Icon(
                Icons.location_on_rounded,
                size: 56,
                color: primaryColor.withValues(alpha: 0.60),
              ),
      ),
    );
  }
}

// ── 칩 ────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final Widget? iconWidget;
  final String label;
  final Color bg;
  final Color textColor;

  const _Chip({
    this.iconWidget,
    required this.label,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget != null) ...[
            iconWidget!,
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
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
