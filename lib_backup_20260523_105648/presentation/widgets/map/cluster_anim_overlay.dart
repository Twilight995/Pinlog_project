import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ─── 데이터 모델 ──────────────────────────────────────────────────────────────

class ClusterItem {
  final double lat;
  final double lng;
  final int count;
  final String emoji;   // 단일 핀: 이모지, 클러스터: ''
  final String? countryFlag;

  const ClusterItem({
    required this.lat,
    required this.lng,
    required this.count,
    this.emoji = '',
    this.countryFlag,
  });

  bool get isCluster => count > 1;
  bool get isCountry => countryFlag != null;
}

// ─── 클러스터 애니메이션 오버레이 ─────────────────────────────────────────────

class ClusterAnimOverlay extends StatefulWidget {
  final List<ClusterItem> prevItems;
  final List<ClusterItem> nextItems;
  final double zoom;
  final double centerLat;
  final double centerLng;
  final VoidCallback onDone;

  const ClusterAnimOverlay({
    super.key,
    required this.prevItems,
    required this.nextItems,
    required this.zoom,
    required this.centerLat,
    required this.centerLng,
    required this.onDone,
  });

  @override
  State<ClusterAnimOverlay> createState() => _ClusterAnimOverlayState();
}

class _ClusterAnimOverlayState extends State<ClusterAnimOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          // 마지막 80ms: 오버레이 전체 페이드아웃 → Mapbox 마커로 자연스럽게 넘김
          final globalOpacity = _ctrl.value < 0.86
              ? 1.0
              : 1.0 - (_ctrl.value - 0.86) / 0.14;

          return Opacity(
            opacity: globalOpacity.clamp(0.0, 1.0),
            child: CustomPaint(
              painter: _ClusterTransitionPainter(
                prevItems: widget.prevItems,
                nextItems: widget.nextItems,
                t: _ctrl.value,
                zoom: widget.zoom,
                centerLat: widget.centerLat,
                centerLng: widget.centerLng,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

// ─── 커스텀 페인터 ────────────────────────────────────────────────────────────

class _ClusterTransitionPainter extends CustomPainter {
  final List<ClusterItem> prevItems;
  final List<ClusterItem> nextItems;
  final double t;  // 0.0 → 1.0
  final double zoom;
  final double centerLat;
  final double centerLng;

  const _ClusterTransitionPainter({
    required this.prevItems,
    required this.nextItems,
    required this.t,
    required this.zoom,
    required this.centerLat,
    required this.centerLng,
  });

  // ── Mercator 투영 (Mapbox 512px 타일 기준) ──────────────────────────────────
  Offset _project(double lat, double lng, Size size) {
    const tileSize = 512.0;
    final scale = tileSize * math.pow(2, zoom);

    double toY(double d) {
      final r = d * math.pi / 180;
      return 0.5 - math.log(math.tan(math.pi / 4 + r / 2)) / (2 * math.pi);
    }

    final cx = (centerLng + 180) / 360 * scale;
    final cy = toY(centerLat) * scale;
    final px = (lng + 180) / 360 * scale;
    final py = toY(lat) * scale;

    return Offset(size.width / 2 + (px - cx), size.height / 2 + (py - cy));
  }

  // ── 스프링 함수 (Nebulous 세포 탄성) ─────────────────────────────────────────
  // 감쇠 스프링: 약간 오버슈트 → 자연스러운 '튀는' 느낌
  double _spring(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const omega = 14.0;  // 진동 주파수
    const zeta = 0.55;   // 감쇠 비율 (< 1 → 약간 오버슈트)
    final wd = omega * math.sqrt(1 - zeta * zeta);
    return 1 -
        math.exp(-zeta * omega * t) *
            (math.cos(wd * t) + (zeta * omega / wd) * math.sin(wd * t));
  }

  // ── 가장 가까운 반대편 클러스터 위치 찾기 ──────────────────────────────────
  Offset _nearestTarget(Offset from, List<ClusterItem> targets, Size size) {
    if (targets.isEmpty) return from;
    Offset best = from;
    double minDist = double.infinity;
    for (final item in targets) {
      final pos = _project(item.lat, item.lng, size);
      final d = (pos - from).distance;
      if (d < minDist) {
        minDist = d;
        best = pos;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Phase 1 (t: 0.0 → 0.50): prev 마커들 → 가장 가까운 next 위치로 수렴 + 소멸
    // Phase 2 (t: 0.50 → 1.0): next 마커들 → 가장 가까운 prev 위치에서 생성 + 스프링
    // 두 페이즈가 t=0.35~0.50 구간에서 살짝 겹쳐 연속감 형성

    // ── Phase 1: 기존 마커 소멸 ──────────────────────────────────────────────
    if (t < 0.55) {
      final phase = (t / 0.55).clamp(0.0, 1.0);
      final curve = Curves.easeIn.transform(phase);

      for (final item in prevItems) {
        final fromPos = _project(item.lat, item.lng, size);
        final toPos = _nearestTarget(fromPos, nextItems, size);

        // 이동: from → to (병합 느낌)
        final pos = Offset.lerp(fromPos, toPos, Curves.easeInCubic.transform(phase))!;

        // 스케일: 1 → 0, 살짝 당겨지는 느낌
        final scale = (1.0 - Curves.easeIn.transform(phase)) *
            (1.0 + 0.08 * math.sin(math.pi * phase)); // 작은 squish
        final opacity = 1.0 - curve;

        if (scale > 0.01) _drawMarker(canvas, pos, item, scale, opacity);
      }
    }

    // ── Phase 2: 새 마커 등장 (스프링) ────────────────────────────────────────
    if (t > 0.38) {
      final phase = ((t - 0.38) / 0.62).clamp(0.0, 1.0);
      final springScale = _spring(phase);
      final opacity = Curves.easeOut.transform(phase.clamp(0.0, 1.0));

      for (final item in nextItems) {
        final toPos = _project(item.lat, item.lng, size);
        final fromPos = _nearestTarget(toPos, prevItems, size);

        // 위치: 이전 클러스터 위치에서 날아오는 느낌
        final pos = Offset.lerp(fromPos, toPos, Curves.easeOutCubic.transform(phase))!;

        _drawMarker(canvas, pos, item, springScale, opacity.clamp(0.0, 1.0));
      }
    }
  }

  void _drawMarker(Canvas canvas, Offset pos, ClusterItem item, double scale, double opacity) {
    if (scale <= 0.01 || opacity <= 0.01) return;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);

    final r = item.isCluster ? 22.0 : 18.0;

    // 그림자
    canvas.drawCircle(
      const Offset(0, 2.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22 * opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );

    // 배경 원
    final bgColor = item.isCluster
        ? const Color(0xFF1C1C1E)
        : Colors.white;
    canvas.drawCircle(Offset.zero, r, Paint()..color = bgColor.withValues(alpha: opacity));

    // 테두리
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = (item.isCluster
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFD0D0D5))
            .withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 텍스트 (이모지 or 숫자)
    final displayText = item.isCountry
        ? (item.countryFlag ?? '🌍')
        : item.isCluster
            ? '${item.count}'
            : item.emoji.isNotEmpty
                ? item.emoji
                : '📍';

    final fontSize = item.isCluster
        ? r * 0.80
        : item.isCountry
            ? r * 0.90
            : r * 0.95;

    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
    )
      ..pushStyle(ui.TextStyle(
        color: item.isCluster
            ? ui.Color.fromRGBO(255, 255, 255, opacity)
            : ui.Color.fromRGBO(28, 28, 30, opacity),
        fontWeight: FontWeight.bold,
      ))
      ..addText(displayText);
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: r * 2.2));
    canvas.drawParagraph(para, Offset(-r * 1.1, -para.height / 2));

    // 클러스터 카운트 뱃지 (카운트리 클러스터용)
    if (item.isCountry && item.count > 1) {
      const badgeR = 9.0;
      const badgeOffset = Offset(14, -14);
      canvas.drawCircle(
        badgeOffset,
        badgeR,
        Paint()..color = const Color(0xFF2C2C2E).withValues(alpha: opacity),
      );
      canvas.drawCircle(
        badgeOffset,
        badgeR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final bp = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 8.5),
      )
        ..pushStyle(ui.TextStyle(
          color: ui.Color.fromRGBO(255, 255, 255, opacity),
          fontWeight: FontWeight.bold,
        ))
        ..addText('${item.count}');
      final bPara = bp.build()
        ..layout(const ui.ParagraphConstraints(width: badgeR * 2));
      canvas.drawParagraph(
        bPara,
        Offset(badgeOffset.dx - badgeR, badgeOffset.dy - bPara.height / 2),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClusterTransitionPainter old) =>
      old.t != t ||
      old.centerLat != centerLat ||
      old.centerLng != centerLng ||
      old.zoom != zoom;
}
