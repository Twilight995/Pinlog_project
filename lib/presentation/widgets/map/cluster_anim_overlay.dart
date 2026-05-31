import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ─── 데이터 모델 ──────────────────────────────────────────────────────────────

class ClusterItem {
  final double lat;
  final double lng;
  final int count;
  final String? countryCode; // 지구본 국가 클러스터용

  const ClusterItem({
    required this.lat,
    required this.lng,
    required this.count,
    this.countryCode,
  });

  bool get isCluster => count > 1;
  bool get isCountry => countryCode != null;
}

// ─── 클러스터 애니메이션 오버레이 ─────────────────────────────────────────────

class ClusterAnimOverlay extends StatefulWidget {
  final List<ClusterItem> prevItems;
  final List<ClusterItem> nextItems;
  final double zoom;
  final double centerLat;
  final double centerLng;
  final Color themeColor;
  final VoidCallback onDone;

  const ClusterAnimOverlay({
    super.key,
    required this.prevItems,
    required this.nextItems,
    required this.zoom,
    required this.centerLat,
    required this.centerLng,
    required this.themeColor,
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
                themeColor: widget.themeColor,
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
  final Color themeColor;

  const _ClusterTransitionPainter({
    required this.prevItems,
    required this.nextItems,
    required this.t,
    required this.zoom,
    required this.centerLat,
    required this.centerLng,
    required this.themeColor,
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

  // 테마 색상에서 어두운 핀 바디 도출
  Color _bodyColor() {
    final hsl = HSLColor.fromColor(themeColor);
    return hsl.withLightness(0.10).withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0)).toColor();
  }

  void _drawMarker(Canvas canvas, Offset pos, ClusterItem item, double scale, double opacity) {
    if (scale <= 0.01 || opacity <= 0.01) return;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);

    final r = item.isCluster ? 22.0 : 18.0;
    final bodyColor = _bodyColor();

    // 글로우
    canvas.drawCircle(
      Offset.zero,
      r + 3,
      Paint()
        ..color = themeColor.withValues(alpha: 0.20 * opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );

    // 그림자
    canvas.drawCircle(
      const Offset(0, 2.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22 * opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );

    // 핀 바디 (테마 기반 다크 컬러)
    canvas.drawCircle(Offset.zero, r, Paint()..color = bodyColor.withValues(alpha: opacity));

    // 테마 컬러 테두리
    final lighter = Color.lerp(themeColor, Colors.white, 0.35)!;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = lighter.withValues(alpha: 0.70 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.isCluster ? 2.5 : 2.0,
    );

    // 상단 하이라이트
    canvas.drawOval(
      Rect.fromLTWH(-r * 0.38, -r * 0.82, r * 0.76, r * 0.38),
      Paint()..color = Colors.white.withValues(alpha: 0.10 * opacity),
    );

    // 내용: 클러스터는 카운트, 단일/국가는 작은 점
    if (item.isCluster) {
      final label = item.count > 99 ? '99+' : '+${item.count}';
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontWeight: ui.FontWeight.w800, fontSize: r * 0.75),
      )
        ..pushStyle(ui.TextStyle(color: ui.Color.fromRGBO(255, 255, 255, opacity)))
        ..addText(label);
      final para = pb.build()..layout(ui.ParagraphConstraints(width: r * 2.2));
      canvas.drawParagraph(para, Offset(-r * 1.1, -para.height / 2));
    } else {
      // 단일 핀 — 테마 색상 작은 원
      canvas.drawCircle(
        Offset.zero,
        r * 0.28,
        Paint()..color = themeColor.withValues(alpha: opacity),
      );
    }

    // 카운트 뱃지 (국가 클러스터용)
    if (item.isCountry && item.count > 1) {
      const badgeR = 9.0;
      const badgeOffset = Offset(14, -14);
      canvas.drawCircle(badgeOffset, badgeR, Paint()..color = bodyColor.withValues(alpha: opacity));
      canvas.drawCircle(
        badgeOffset,
        badgeR,
        Paint()
          ..color = lighter.withValues(alpha: 0.6 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
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
      old.zoom != zoom ||
      old.themeColor != themeColor;
}

// ─── 지구본 ↔ 지도 전환 오버레이 ─────────────────────────────────────────────

class GlobeTransitionOverlay extends StatefulWidget {
  final List<ClusterItem> pins;
  final double zoom;
  final double centerLat;
  final double centerLng;
  final Color themeColor;
  final bool entering; // true = 지구본 진입 (핀 수렴), false = 지도 복귀 (핀 확산)
  final VoidCallback onDone;

  const GlobeTransitionOverlay({
    super.key,
    required this.pins,
    required this.zoom,
    required this.centerLat,
    required this.centerLng,
    required this.themeColor,
    required this.entering,
    required this.onDone,
  });

  @override
  State<GlobeTransitionOverlay> createState() => _GlobeTransitionOverlayState();
}

class _GlobeTransitionOverlayState extends State<GlobeTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.entering
          ? const Duration(milliseconds: 1300)
          : const Duration(milliseconds: 950),
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
        builder: (ctx, child) => Opacity(
          opacity: widget.entering
              ? 1.0
              : (_ctrl.value < 0.85 ? 1.0 : (1.0 - (_ctrl.value - 0.85) / 0.15).clamp(0.0, 1.0)),
          child: CustomPaint(
            painter: _GlobeTransitionPainter(
              pins: widget.pins,
              t: _ctrl.value,
              zoom: widget.zoom,
              centerLat: widget.centerLat,
              centerLng: widget.centerLng,
              themeColor: widget.themeColor,
              entering: widget.entering,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _GlobeTransitionPainter extends CustomPainter {
  final List<ClusterItem> pins;
  final double t;
  final double zoom;
  final double centerLat;
  final double centerLng;
  final Color themeColor;
  final bool entering;

  const _GlobeTransitionPainter({
    required this.pins,
    required this.t,
    required this.zoom,
    required this.centerLat,
    required this.centerLng,
    required this.themeColor,
    required this.entering,
  });

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

  double _spring(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const omega = 11.0;
    const zeta = 0.58;
    final wd = omega * math.sqrt(1 - zeta * zeta);
    return 1 - math.exp(-zeta * omega * t) *
        (math.cos(wd * t) + (zeta * omega / wd) * math.sin(wd * t));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final screenCenter = Offset(size.width / 2, size.height / 2);

    for (final pin in pins) {
      final pinPos = _project(pin.lat, pin.lng, size);

      late Offset pos;
      late double scale;
      late double opacity;

      if (entering) {
        final curve = Curves.easeInCubic.transform(t);
        pos = Offset.lerp(pinPos, screenCenter, curve)!;
        scale = 1.0 - Curves.easeIn.transform(t);
        opacity = (1.0 - curve * 1.3).clamp(0.0, 1.0);
      } else {
        final curve = Curves.easeOutCubic.transform(t);
        final spring = _spring(t);
        pos = Offset.lerp(screenCenter, pinPos, curve)!;
        scale = spring.clamp(0.0, 1.25);
        opacity = (t * 3.5).clamp(0.0, 1.0);
      }

      if (scale > 0.02 && opacity > 0.02) {
        _drawPin(canvas, pos, pin, scale, opacity);
      }
    }
  }

  Color _bodyColor() {
    final hsl = HSLColor.fromColor(themeColor);
    return hsl
        .withLightness(0.10)
        .withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
        .toColor();
  }

  void _drawPin(Canvas canvas, Offset pos, ClusterItem item, double scale, double opacity) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);

    final r = item.isCluster ? 20.0 : 16.0;
    final bodyColor = _bodyColor();
    final lighter = Color.lerp(themeColor, Colors.white, 0.35)!;

    canvas.drawCircle(
      Offset.zero, r + 3,
      Paint()
        ..color = themeColor.withValues(alpha: 0.18 * opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      const Offset(0, 2),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset.zero, r, Paint()..color = bodyColor.withValues(alpha: opacity));
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..color = lighter.withValues(alpha: 0.65 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.isCluster ? 2.0 : 1.8,
    );

    if (item.isCluster) {
      final label = item.count > 99 ? '99+' : '+${item.count}';
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontWeight: ui.FontWeight.w800,
          fontSize: r * 0.75,
        ),
      )
        ..pushStyle(ui.TextStyle(color: ui.Color.fromRGBO(255, 255, 255, opacity)))
        ..addText(label);
      final para = pb.build()..layout(ui.ParagraphConstraints(width: r * 2.2));
      canvas.drawParagraph(para, Offset(-r * 1.1, -para.height / 2));
    } else {
      canvas.drawCircle(
        Offset.zero, r * 0.28,
        Paint()..color = themeColor.withValues(alpha: opacity),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobeTransitionPainter old) => old.t != t;
}
