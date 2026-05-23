import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/common/glass_card.dart';

/// 핀 상세 화면 — 펜 디자인(`TAcfR`)을 Flutter로 옮긴 풀스크린.
///
/// 흐름: 히어로(380) → 컨텐츠(타이틀·감정카드·날씨/잔향 페어·동행자) → 액션(편집/삭제).
class PinDetailScreen extends ConsumerWidget {
  final String pinId;
  const PinDetailScreen({super.key, required this.pinId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(pinsProvider);
    final pin = pins.where((p) => p.id == pinId).firstOrNull;
    if (pin == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0820),
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0820),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroBlock(pin: pin)),
          SliverToBoxAdapter(child: _ContentBlock(pin: pin)),
          SliverToBoxAdapter(child: _BottomActions(pinId: pin.id)),
        ],
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  final PinModel pin;
  const _HeroBlock({required this.pin});

  @override
  Widget build(BuildContext context) {
    final hasPhotos = pin.photoPaths.isNotEmpty;
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 380,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 사진 또는 분위기 플레이스홀더
            if (hasPhotos)
              Image.file(
                File(pin.photoPaths.first),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _AtmosphericPlaceholder(),
              )
            else
              const _AtmosphericPlaceholder(),

            // 상단 글래스 버튼 (back / more)
            Positioned(
              top: topPad + 12,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GlassCircleBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _GlassCircleBtn(
                    icon: Icons.more_horiz_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // 하단 카테고리 펄
            Positioned(
              left: 20,
              bottom: 32,
              child: _CategoryPill(shape: pin.pinShape),
            ),

            // 스와이프 도트 (2장 이상일 때만)
            if (pin.photoPaths.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: _SwipeDots(
                    count: pin.photoPaths.length,
                    active: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 사진 없을 때 표시되는 시네마틱 골든아워 배경.
///
/// 펜 디자인 `YVIc6` photo bg의 5겹 fill을 Flutter로 옮긴 것:
/// 베이스 그라디언트 + 선글로우 + 로즈 헤이즈 + 딥 와인 + 골든 앰비언트.
class _AtmosphericPlaceholder extends StatelessWidget {
  const _AtmosphericPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 베이스 5스톱 선형 (top-right → bottom-left)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFFFFEACC),
                Color(0xFFF8BB94),
                Color(0xFFDE8C8A),
                Color(0xFF9F4F66),
                Color(0xFF5B2C49),
              ],
              stops: [0.0, 0.28, 0.55, 0.82, 1.0],
            ),
          ),
        ),
        // 2. 선글로우 (top-right) — 햇살
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.64, -0.64),
              radius: 0.85,
              colors: [
                Color(0xB3FFF1D1),
                Color(0x80FFE0A1),
                Color(0x40FFCF8C),
                Color(0x12FFCF8C),
                Color(0x00FFCF8C),
              ],
              stops: [0.0, 0.2, 0.5, 0.78, 1.0],
            ),
          ),
        ),
        // 3. 로즈 헤이즈 (mid-left)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.76, 0.0),
              radius: 0.95,
              colors: [
                Color(0x66FFAFA8),
                Color(0x40FF9A9E),
                Color(0x1FFF9A9E),
                Color(0x0AFF9A9E),
                Color(0x00FF9A9E),
              ],
              stops: [0.0, 0.3, 0.6, 0.85, 1.0],
            ),
          ),
        ),
        // 4. 딥 와인 풀 (bottom-right) — 무드 그라운딩
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.56, 1.0),
              radius: 1.0,
              colors: [
                Color(0xB33D1838),
                Color(0x663D1838),
                Color(0x333D1838),
                Color(0x0F3D1838),
                Color(0x003D1838),
              ],
              stops: [0.0, 0.3, 0.55, 0.82, 1.0],
            ),
          ),
        ),
        // 5. 골든 앰비언트 (center) — 빛이 머무는 느낌
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 0.5,
              colors: [
                Color(0x33FFD899),
                Color(0x14FFD899),
                Color(0x00FFD899),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String shape;
  const _CategoryPill({required this.shape});

  @override
  Widget build(BuildContext context) {
    final emoji = AppConstants.pinShapeEmojis[shape] ?? '📍';
    final name = AppConstants.pinShapeNames[shape] ?? shape;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 38,
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xE61A0F3D),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: AppTokens.fontBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeDots extends StatelessWidget {
  final int count;
  final int active;
  const _SwipeDots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────

class _ContentBlock extends StatelessWidget {
  final PinModel pin;
  const _ContentBlock({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 코스믹 글로우 (절대 배경)
        const Positioned.fill(child: IgnorePointer(child: _ContentGlows())),

        // 실제 컨텐츠
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TitleBlock(pin: pin),
              const SizedBox(height: 22),
              _EmotionCard(pin: pin),
              const SizedBox(height: 22),
              _MomentPair(pin: pin),
              if (pin.companions.isNotEmpty) ...[
                const SizedBox(height: 22),
                _CompanionsSection(companions: pin.companions),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 컨텐츠 영역 코스믹 글로우 — 펜 `ST0eQ`의 3개 radial fill.
class _ContentGlows extends StatelessWidget {
  const _ContentGlows();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: const [
        // 보라 좌측 중앙
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1.24, 0.0),
              radius: 1.5,
              colors: [
                Color(0x407C5AD9),
                Color(0x335F44B0),
                Color(0x1F4A2C8C),
                Color(0x0F4A2C8C),
                Color(0x004A2C8C),
              ],
              stops: [0.0, 0.3, 0.55, 0.78, 1.0],
            ),
          ),
        ),
        // 와인 우측 중하단
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.4, 0.3),
              radius: 1.4,
              colors: [
                Color(0x339D2A5C),
                Color(0x267E2447),
                Color(0x147A1F44),
                Color(0x0A7A1F44),
                Color(0x007A1F44),
              ],
              stops: [0.0, 0.35, 0.65, 0.85, 1.0],
            ),
          ),
        ),
        // 애프리콧 우하단
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.2, 1.2),
              radius: 1.2,
              colors: [
                Color(0x40F5B073),
                Color(0x2EE89A5C),
                Color(0x17D88A4F),
                Color(0x08D88A4F),
                Color(0x00D88A4F),
              ],
              stops: [0.0, 0.3, 0.6, 0.85, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final PinModel pin;
  const _TitleBlock({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pin.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: Colors.white,
            fontFamily: AppTokens.fontDisplay,
          ),
        ),
        const SizedBox(height: 8),
        _MetaRow(pin: pin),
      ],
    );
  }
}

class _MetaRow extends StatefulWidget {
  final PinModel pin;
  const _MetaRow({required this.pin});

  @override
  State<_MetaRow> createState() => _MetaRowState();
}

class _MetaRowState extends State<_MetaRow> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final marks = await placemarkFromCoordinates(
        widget.pin.latitude,
        widget.pin.longitude,
      );
      if (!mounted || marks.isEmpty) return;
      final p = marks.first;
      final parts = [p.administrativeArea, p.subLocality, p.locality]
          .where((s) => s != null && s.isNotEmpty)
          .toSet()
          .toList();
      if (parts.isNotEmpty && mounted) {
        setState(() => _address = parts.take(2).join(' '));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy년 M월 d일').format(widget.pin.createdAt);
    return Row(
      children: [
        Text(
          dateStr,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            fontFamily: AppTokens.fontBody,
          ),
        ),
        if (_address != null) ...[
          const SizedBox(width: 10),
          const Text(
            '·',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.location_on_outlined,
            size: 12,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            _address!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmotionCard extends StatelessWidget {
  final PinModel pin;
  const _EmotionCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    final isPositive = pin.emotion == AppConstants.emotions.first;
    final gradient = isPositive
        ? const [Color(0xFFFFB4C7), Color(0xFFE26AA0)]
        : const [Color(0xFFB8D8F2), Color(0xFF7BA8CF)];
    final emoji = isPositive ? '💖' : '💧';
    final caption = _intensityCaption(pin.intensityLevel);
    final shadowColor = gradient.last.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.emotion,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Color(0xCCFFFFFF),
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(5, (i) {
              final filled = i < pin.intensityLevel;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: filled
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: filled
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: filled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _intensityCaption(int v) {
    switch (v) {
      case 1:
        return '잠깐 스쳐간 느낌';
      case 2:
        return '기록할 만한 순간';
      case 3:
        return '오래 기억하고 싶어요';
      case 4:
        return '마음 깊이 남는 시간';
      case 5:
        return '잊지 못할 한 순간';
      default:
        return '';
    }
  }
}

class _MomentPair extends StatelessWidget {
  final PinModel pin;
  const _MomentPair({required this.pin});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _WeatherCard(weather: pin.weather)),
          const SizedBox(width: 12),
          Expanded(child: _AfterglowCard(createdAt: pin.createdAt)),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final String weather;
  const _WeatherCard({required this.weather});

  ({String emoji, List<Color> gradient, String caption}) _meta(String label) {
    if (label.contains('맑음')) {
      return (
        emoji: '☀️',
        gradient: const [Color(0xFFFFD27A), Color(0xFFF59E5C)],
        caption: '따스한 햇살이 닿던 날',
      );
    }
    if (label.contains('비')) {
      return (
        emoji: '🌧',
        gradient: const [Color(0xFF8FA8D8), Color(0xFF4A6FB5)],
        caption: '빗방울이 마음을 두드리던 날',
      );
    }
    if (label.contains('흐림')) {
      return (
        emoji: '☁️',
        gradient: const [Color(0xFFCABBE0), Color(0xFF8B7BAF)],
        caption: '잿빛 하늘이 포근하던 날',
      );
    }
    if (label.contains('눈')) {
      return (
        emoji: '🌨',
        gradient: const [Color(0xFFE7F0FA), Color(0xFFA8C9E8)],
        caption: '하얗게 내려앉던 고요',
      );
    }
    if (label.contains('바람')) {
      return (
        emoji: '🌬',
        gradient: const [Color(0xFFB3E6D3), Color(0xFF55AE8E)],
        caption: '시원한 바람결이 스치던 날',
      );
    }
    return (
      emoji: '🌤',
      gradient: const [Color(0xFFFFD27A), Color(0xFFF59E5C)],
      caption: '오늘의 공기',
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta(weather);
    final shadowColor = m.gradient.last.withValues(alpha: 0.4);
    final words = weather.trim().split(' ');
    final name = words.length > 1 ? words.sublist(1).join(' ') : weather;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: m.gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(m.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: AppTokens.fontBody,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            m.caption,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: Color(0xCCFFFFFF),
              height: 1.4,
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterglowCard extends StatelessWidget {
  final DateTime createdAt;
  const _AfterglowCard({required this.createdAt});

  int get _daysAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysAgo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0A3C), Color(0xFF150826)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF3A2A6B), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3겹 합성 오브
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 바깥 글로우
                Positioned(
                  left: -8,
                  top: -8,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x59E26AA0), Color(0x00E26AA0)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                // 코어
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(-0.2, -0.2),
                        colors: [
                          Color(0xFFFFE9C7),
                          Color(0xFFFFB4C7),
                          Color(0xFF7C3AED),
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // 하이라이트
                Positioned(
                  left: 11,
                  top: 9,
                  child: Container(
                    width: 16,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xD9FFFFFF), Color(0x00FFFFFF)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (days > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$days',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: Colors.white,
                    fontFamily: AppTokens.fontBody,
                  ),
                ),
                const SizedBox(width: 5),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    '일 전',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA78BFA),
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ),
              ],
            )
          else
            const Text(
              '오늘',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            '그날의 공기가 다시 머문다',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
              height: 1.4,
              fontFamily: AppTokens.fontBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionsSection extends StatelessWidget {
  final List<String> companions;
  const _CompanionsSection({required this.companions});

  static const _palettes = <List<Color>>[
    [Color(0xFFFFE9A8), Color(0xFFF2A66B)],
    [Color(0xFFBFEFE4), Color(0xFF5BB89E)],
    [Color(0xFFF5C9E0), Color(0xFFD89BC4)],
    [Color(0xFFC7BFFF), Color(0xFF9D8BE0)],
    [Color(0xFFBFDBFE), Color(0xFF93C5FD)],
  ];

  List<Color> _paletteFor(String name) {
    final i = name.hashCode.abs() % _palettes.length;
    return _palettes[i];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 13,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 8),
            Text(
              '함께한 사람',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.textMuted,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: companions.map((name) {
            return GlassCard(
              radius: 999,
              blurSigma: 18,
              intensity: 1.3,
              borderColor: Colors.white.withValues(alpha: 0.30),
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _paletteFor(name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: AppTokens.fontBody,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Actions ──────────────────────────────────────────────────────────────

class _BottomActions extends ConsumerWidget {
  final String pinId;
  const _BottomActions({required this.pinId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        // 액션 영역 코스믹 글로우
        const Positioned.fill(child: IgnorePointer(child: _ActionsGlows())),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomPad),
          child: Row(
            children: [
              Expanded(child: _EditButton(pinId: pinId)),
              const SizedBox(width: 12),
              Expanded(child: _DeleteButton(pinId: pinId)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsGlows extends StatelessWidget {
  const _ActionsGlows();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: const [
        // 베이스 다크
        DecoratedBox(decoration: BoxDecoration(color: Color(0xFF0E0820))),
        // 애프리콧 우측
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.1, -0.1),
              radius: 1.4,
              colors: [
                Color(0x40F5B073),
                Color(0x26E89A5C),
                Color(0x14D88A4F),
                Color(0x00D88A4F),
              ],
              stops: [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
        // 보라 좌측
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1.16, 0.1),
              radius: 1.1,
              colors: [
                Color(0x407C5AD9),
                Color(0x265F44B0),
                Color(0x124A2C8C),
                Color(0x004A2C8C),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        // 와인 하단 중앙
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 1.4),
              radius: 1.6,
              colors: [
                Color(0x269D2A5C),
                Color(0x129D2A5C),
                Color(0x009D2A5C),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  final String pinId;
  const _EditButton({required this.pinId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // TODO: 편집 위자드 진입
      },
      child: GlassCard(
        radius: 18,
        blurSigma: 22,
        intensity: 1.2,
        borderColor: Colors.white.withValues(alpha: 0.30),
        child: const SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '편집',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: AppTokens.fontDisplay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends ConsumerWidget {
  final String pinId;
  const _DeleteButton({required this.pinId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E0A3C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '이 핀을 지울까요?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: const Text(
              '지운 핀은 복구할 수 없어요.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  '취소',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  '삭제',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        if (!context.mounted) return;
        await ref.read(pinsProvider.notifier).remove(pinId);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: GlassCard(
        radius: 18,
        blurSigma: 22,
        intensity: 1.4,
        tint: const Color(0xFFFF6B6B),
        borderColor: const Color(0x80FF6B6B),
        child: const SizedBox(
          height: 56,
          child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: Color(0xFFFF6B6B),
            ),
            SizedBox(width: 8),
            Text(
              '삭제',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF6B6B),
                fontFamily: AppTokens.fontDisplay,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
