import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings, Size;

import '../../../application/providers/donghaeng_provider.dart';
import '../../../application/providers/meeting_provider.dart';
import '../../../application/providers/pin_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/services/recap_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/camera_prefs.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../data/models/pin_model.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/map/cluster_anim_overlay.dart';
import '../../widgets/map/donghaeng_panel.dart';
import '../../widgets/meeting/meeting_bottom_sheet.dart';
import '../../widgets/map/filter_sheet.dart';
import '../../widgets/meeting/meeting_create_sheet.dart';
import '../../widgets/recap/recap_popup.dart';
import '../pin_wizard/pin_wizard_screen.dart';
import '../../widgets/map/pin_detail_sheet.dart';
import '../social/friends_screen.dart';
import '../../../application/services/social_service.dart';
import '../../../application/providers/friends_provider.dart';
import '../../../application/services/map_controls_prefs.dart';

// ─── 지구본 모드 상수 ──────────────────────────────────────────────────────────
const double _kGlobeEnterZoom = 4.5;
const double _kGlobeExitZoom = 5.8; // 히스테리시스 — 진입보다 높게 설정
const double _kGlobeTargetZoom = 1.5;

// ─── 클러스터 모델 ─────────────────────────────────────────────────────────────

class _Cluster {
  final List<PinModel> pins;
  final double lat;
  final double lng;
  final String? countryCode; // null = 일반 클러스터, non-null = 지구본 국가 클러스터
  const _Cluster({
    required this.pins,
    required this.lat,
    required this.lng,
    this.countryCode,
  });
}

const _kFallbackFlagSvg = 'lib/img/flag/flag-triangle-right.svg';

const _countrySvgs = <String, String>{
  'KR': 'lib/img/flag/flag-for-south-korea-svgrepo-com.svg',
  'US': 'lib/img/flag/flag-usa-solid-svgrepo-com.svg',
  'CN': 'lib/img/flag/flag-china-solid-svgrepo-com.svg',
  'JP': 'lib/img/flag/flag-for-japan-svgrepo-com.svg',
  'TW': 'lib/img/flag/flag-for-taiwan-svgrepo-com.svg',
  'GB': 'lib/img/flag/flag-for-united-kingdom-svgrepo-com.svg',
  'FR': 'lib/img/flag/flag-for-france-svgrepo-com.svg',
  'DE': 'lib/img/flag/flag-for-germany-svgrepo-com.svg',
  'IT': 'lib/img/flag/flag-for-italy-svgrepo-com.svg',
  'ES': 'lib/img/flag/flag-for-spain-svgrepo-com.svg',
  'TH': 'lib/img/flag/flag-for-thailand-svgrepo-com.svg',
  'VN': 'lib/img/flag/flag-for-vietnam-svgrepo-com.svg',
  'SG': 'lib/img/flag/flag-for-singapore-svgrepo-com.svg',
  'MY': 'lib/img/flag/flag-for-malaysia-svgrepo-com.svg',
  'ID': 'lib/img/flag/flag-for-indonesia-svgrepo-com.svg',
  'PH': 'lib/img/flag/flag-for-philippines-svgrepo-com.svg',
  'AU': 'lib/img/flag/flag-for-australia-svgrepo-com.svg',
  'CA': 'lib/img/flag/canada-maple-leaf-svgrepo-com.svg',
  'AT': 'lib/img/flag/flag-for-flag-austria-svgrepo-com.svg',
  'BR': 'lib/img/flag/flag-for-flag-brazil-svgrepo-com.svg',
  'KH': 'lib/img/flag/flag-for-flag-cambodia-svgrepo-com.svg',
  'DK': 'lib/img/flag/flag-for-flag-denmark-svgrepo-com.svg',
  'EG': 'lib/img/flag/flag-for-flag-egypt-svgrepo-com.svg',
  'GR': 'lib/img/flag/flag-for-flag-greece-svgrepo-com.svg',
  'HK': 'lib/img/flag/flag-for-flag-hong-kong-sar-china-svgrepo-com.svg',
  'HU': 'lib/img/flag/flag-for-flag-hungary-svgrepo-com.svg',
  'IN': 'lib/img/flag/flag-for-flag-india-svgrepo-com.svg',
  'LA': 'lib/img/flag/flag-for-flag-laos-svgrepo-com.svg',
  'MV': 'lib/img/flag/flag-for-flag-maldives-svgrepo-com.svg',
  'MX': 'lib/img/flag/flag-for-flag-mexico-svgrepo-com.svg',
  'MM': 'lib/img/flag/flag-for-flag-myanmar-burma-svgrepo-com.svg',
  'NP': 'lib/img/flag/flag-for-flag-nepal-svgrepo-com.svg',
  'NL': 'lib/img/flag/flag-for-flag-netherlands-svgrepo-com.svg',
  'NZ': 'lib/img/flag/flag-for-flag-new-zealand-svgrepo-com.svg',
  'NO': 'lib/img/flag/flag-for-flag-norway-svgrepo-com.svg',
  'PT': 'lib/img/flag/flag-for-flag-portugal-svgrepo-com.svg',
  'QA': 'lib/img/flag/flag-for-flag-qatar-svgrepo-com.svg',
  'LK': 'lib/img/flag/flag-for-flag-sri-lanka-svgrepo-com.svg',
  'SE': 'lib/img/flag/flag-for-flag-sweden-svgrepo-com.svg',
  'CH': 'lib/img/flag/flag-for-flag-switzerland-svgrepo-com.svg',
  'TR': 'lib/img/flag/flag-for-flag-turkey-svgrepo-com.svg',
  'AE': 'lib/img/flag/united-arab-emirates-svgrepo-com.svg',
};

// 핀 카테고리 → SVG 경로 (정적 마커용)
String _shapeSvgPath(String shape) =>
    AppConstants.pinShapeSvgs[shape] ?? '';

// ─── 마커 비트맵 생성 (캐시됨) — 테마 어웨어 디자인 ──────────────────────────

final _markerCache = <String, Uint8List>{};

// 테마 색상에서 어두운 핀 바디 색상 도출
Color _pinBodyColor(Color theme) {
  // HSL 기반으로 채도 유지 + 밝기를 매우 어둡게
  final hsl = HSLColor.fromColor(theme);
  return hsl.withLightness(0.10).withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0)).toColor().withValues(alpha: 0.96);
}

// 테마 색상에서 테두리 그라디언트 컬러 도출
List<Color> _pinBorderGradient(Color theme) {
  final lighter = Color.lerp(theme, Colors.white, 0.35)!;
  final darker  = Color.lerp(theme, Colors.black, 0.15)!;
  return [lighter, darker];
}

Future<Uint8List> _buildMarkerBitmap({
  required bool isCluster,
  required Color themeColor,
  Color? bodyColorOverride,
  int count = 0,
  String svgPath = '',
  // 클러스터 아이콘 크로스페이드: 이전 SVG + 진행도 (0.0 = 이전 아이콘, 1.0 = 새 아이콘)
  String fadeSvgPath = '',
  double fadeProgress = 1.0,
  required double pixelRatio,
}) async {
  final tc = themeColor.toARGB32();
  final bc = bodyColorOverride?.toARGB32() ?? 0;
  final key = '${isCluster}_${count}_${svgPath}_${fadeSvgPath}_${fadeProgress.toStringAsFixed(2)}_${tc}_${bc}_${pixelRatio.toStringAsFixed(1)}';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  // 글로우 sigma(7px)×3 = 21px 여백 확보: 사각형 아티팩트 방지
  final logicalSize = isCluster ? 88.0 : 80.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pixelRatio * (isCluster ? 20.0 : 17.0);
  final gradientRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

  final bodyColor = bodyColorOverride ?? _pinBodyColor(themeColor);
  final borderColors = _pinBorderGradient(themeColor);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));
  // blur가 canvas 모서리에서 사각형으로 잘리지 않도록 원형 clip 적용
  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, pxSize, pxSize)));

  // ── 1. 글로우 헤일로 (테마 색상) ─────────────────────────────────────────
  canvas.drawCircle(
    Offset(cx, cy),
    r + pixelRatio * 3,
    Paint()
      ..color = themeColor.withValues(alpha: 0.28)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 7),
  );

  // ── 2. 드롭 섀도우 ───────────────────────────────────────────────────────
  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 2.5),
    r,
    Paint()
      ..color = const Color(0x50000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 5),
  );

  // ── 3. 핀 바디 (테마 기반 다크 컬러) ─────────────────────────────────────
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bodyColor);

  // ── 4. 테마 그라디언트 테두리 ─────────────────────────────────────────────
  final borderW = (isCluster ? 3.0 : 2.4) * pixelRatio;
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

  // ── 5. 상단 하이라이트 쉰 ─────────────────────────────────────────────────
  canvas.drawOval(
    Rect.fromLTWH(cx - r * 0.38, cy - r * 0.82, r * 0.76, r * 0.38),
    Paint()..color = const Color(0x18FFFFFF),
  );

  // ── 6. SVG 아이콘 (크로스페이드 지원) ────────────────────────────────────
  Future<void> drawSvg(String path, double alpha) async {
    if (path.isEmpty || alpha <= 0.0) return;
    try {
      final loader = SvgAssetLoader(path);
      final info = await vg.loadPicture(loader, null);
      final iconPx = r * 1.08;
      final scale = iconPx / math.max(info.size.width, info.size.height);
      final scaledW = info.size.width * scale;
      final scaledH = info.size.height * scale;
      final ox = cx - scaledW / 2;
      final oy = cy - scaledH / 2;

      canvas.saveLayer(
        Rect.fromLTWH(ox, oy, scaledW, scaledH),
        Paint()..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255),
      );
      canvas.save();
      canvas.translate(ox, oy);
      canvas.scale(scale);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, info.size.width, info.size.height),
        Paint()..colorFilter = const ui.ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      canvas.drawPicture(info.picture);
      canvas.restore();
      canvas.restore();
      canvas.restore();
      info.picture.dispose();
    } catch (_) {
      // SVG 로드/파싱 실패 시 아이콘 없이 핀만 표시
    }
  }

  if (svgPath.isNotEmpty) {
    if (fadeSvgPath.isNotEmpty && fadeProgress < 1.0) {
      // 크로스페이드: 이전 아이콘 페이드아웃 + 새 아이콘 페이드인
      await drawSvg(fadeSvgPath, 1.0 - fadeProgress);
      await drawSvg(svgPath, fadeProgress);
    } else {
      await drawSvg(svgPath, 1.0);
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  // 크로스페이드 중간 프레임은 캐시하지 않음
  if (fadeProgress >= 1.0 || fadeSvgPath.isEmpty) {
    _markerCache[key] = bytes;
  }
  return bytes;
}

// 동행 참여자 마커 (닉네임 이니셜 + 컬러 원)
Future<Uint8List> _buildDonghaengMarkerBitmap({
  required String nickname,
  required String uid,
  required double pixelRatio,
  required Color themeColor,
  bool isMe = false,
}) async {
  const colors = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFFEC4899),
  ];
  final color = isMe
      ? themeColor
      : (uid.isEmpty ? colors[0] : colors[uid.codeUnitAt(0) % colors.length]);
  final initial = isMe ? '나' : (nickname.isNotEmpty ? nickname[0] : '?');

  const logicalSize = 54.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pxSize / 2 - pixelRatio * 4;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));
  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, pxSize, pxSize)));

  // glow
  canvas.drawCircle(
    Offset(cx, cy), r + pixelRatio * 3,
    Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 6),
  );
  // filled circle
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.18));
  // border
  canvas.drawCircle(
    Offset(cx, cy), r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pixelRatio * 2.2
      ..color = color,
  );
  // text
  final tp = TextPainter(
    text: TextSpan(
      text: initial,
      style: TextStyle(
        color: color,
        fontSize: pixelRatio * 14,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

// 약속 장소 핀 — 친구 프로필 사진 (없으면 이니셜) + 테마 테두리
Future<Uint8List> _buildMeetingTargetBitmap({
  required Color themeColor,
  required double pixelRatio,
  String? avatarUrl,
  String? nickname,
}) async {
  const logicalSize = 80.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pixelRatio * 17.0;
  final gradientRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
  final borderColors = _pinBorderGradient(themeColor);

  // 프로필 사진 네트워크 로드 시도
  ui.Image? avatarImg;
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    try {
      final res = await http
          .get(Uri.parse(avatarUrl))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(
          res.bodyBytes,
          targetWidth: (r * 2).ceil(),
          targetHeight: (r * 2).ceil(),
        );
        avatarImg = (await codec.getNextFrame()).image;
      }
    } catch (_) {}
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));
  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, pxSize, pxSize)));

  // 글로우
  canvas.drawCircle(
    Offset(cx, cy),
    r + pixelRatio * 3,
    Paint()
      ..color = themeColor.withValues(alpha: 0.32)
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

  if (avatarImg != null) {
    // 프로필 사진을 원형 clip으로 채움
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
    paintImage(
      canvas: canvas,
      rect: Rect.fromCircle(center: Offset(cx, cy), radius: r),
      image: avatarImg,
      fit: BoxFit.cover,
    );
    canvas.restore();
    avatarImg.dispose();
  } else {
    // 이니셜 fallback
    final bodyColor = _pinBodyColor(themeColor);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bodyColor);
    final initial =
        nickname != null && nickname.isNotEmpty ? nickname[0] : '?';
    final tp = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: pixelRatio * 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  // 테마 그라디언트 테두리
  final borderW = 2.8 * pixelRatio;
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
  // 상단 하이라이트
  canvas.drawOval(
    Rect.fromLTWH(cx - r * 0.38, cy - r * 0.82, r * 0.76, r * 0.38),
    Paint()..color = const Color(0x22FFFFFF),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

// 지구본 모드 국가 마커 (국기 SVG + 카운트 뱃지) — 테마 색 적용
Future<Uint8List> _buildCountryMarkerBitmap({
  required String countryCode,
  required int count,
  required double pixelRatio,
  required Color themeColor,
}) async {
  final tc = themeColor.toARGB32();
  final key =
      'country_${countryCode}_${count}_${pixelRatio.toStringAsFixed(1)}_$tc';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  const logicalSize = 58.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pxSize / 2 - pixelRatio * 2;
  final gradientRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

  final bodyColor = _pinBodyColor(themeColor);
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
  // 그림자
  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 2.5),
    r,
    Paint()
      ..color = const Color(0x50000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 5),
  );
  // 다크 바디
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bodyColor);
  // 테마 그라디언트 테두리
  final borderW = pixelRatio * 2.4;
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

  // 국기 — 국가별 SVG 우선, 없으면 일반 깃발 SVG 사용
  final flagSvgPath = _countrySvgs[countryCode] ?? _kFallbackFlagSvg;
  try {
    final loader = SvgAssetLoader(flagSvgPath);
    final info = await vg.loadPicture(loader, null);
    final iconPx = r * 0.72;
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
      Paint()..colorFilter = const ui.ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
    canvas.drawPicture(info.picture);
    canvas.restore();
    canvas.restore();
    canvas.restore();
    info.picture.dispose();
  } catch (_) {
    // SVG 로드 실패 시 아이콘 없이 원형 마커만 표시
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  _markerCache[key] = bytes;
  return bytes;
}

Future<Uint8List> _buildNumberedMarkerBitmap(
  int number,
  double pixelRatio, {
  Color bgColor = AppColors.primary,
  Color textColor = Colors.white,
  Color borderColor = Colors.white,
  String svgPath = '',
}) async {
  final key = 'num_${number}_${pixelRatio.toStringAsFixed(1)}_${bgColor.toARGB32()}_$svgPath';
  if (_markerCache.containsKey(key)) return _markerCache[key]!;

  // 글로우 여백 확보를 위해 캔버스를 핀과 동일한 크기로 확장
  const logicalSize = 88.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;
  final r = pixelRatio * 21.0;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));
  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, pxSize, pxSize)));

  // 1. 글로우
  canvas.drawCircle(
    Offset(cx, cy),
    r + pixelRatio * 3,
    Paint()
      ..color = bgColor.withValues(alpha: 0.28)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 7),
  );

  // 2. 드롭 섀도우
  canvas.drawCircle(
    Offset(cx, cy + pixelRatio * 2.5),
    r,
    Paint()
      ..color = const Color(0x50000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 5),
  );

  // 3. 핀 바디
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = bgColor);

  // 4. 테두리
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = borderColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = pixelRatio * 2,
  );

  // 5. 상단 하이라이트
  canvas.drawOval(
    Rect.fromLTWH(cx - r * 0.38, cy - r * 0.82, r * 0.76, r * 0.38),
    Paint()..color = const Color(0x18FFFFFF),
  );

  // 6. SVG 카테고리 아이콘 또는 숫자 (SVG 없을 때)
  if (svgPath.isNotEmpty) {
    try {
      final loader = SvgAssetLoader(svgPath);
      final info = await vg.loadPicture(loader, null);
      final iconPx = r * 0.85;
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
        Paint()..colorFilter = const ui.ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      canvas.drawPicture(info.picture);
      canvas.restore();
      canvas.restore();
      canvas.restore();
      info.picture.dispose();
    } catch (_) {
      // SVG 로드 실패 시 무시 (숫자 배지만 표시)
    }
  } else {
    // SVG 없을 때: 숫자를 핀 중앙에 표시
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontWeight: ui.FontWeight.w800, fontSize: 14 * pixelRatio),
    )..pushStyle(ui.TextStyle(color: ui.Color(textColor.toARGB32())))
     ..addText('$number');
    final para = pb.build()..layout(ui.ParagraphConstraints(width: pxSize));
    canvas.drawParagraph(para, Offset(cx - para.maxIntrinsicWidth / 2, cy - para.height / 2));
  }

  // 7. 순번 배지 (SVG 있을 때 우상단에 흰 원 + 테마색 숫자)
  if (svgPath.isNotEmpty) {
    final badgeR = pixelRatio * 9.0;
    final badgeX = cx + r * 0.62;
    final badgeY = cy - r * 0.62;

    // 배지 그림자
    canvas.drawCircle(
      Offset(badgeX, badgeY + pixelRatio),
      badgeR,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 1.5),
    );
    // 배지 배경 (항상 흰색)
    canvas.drawCircle(Offset(badgeX, badgeY), badgeR, Paint()..color = Colors.white);
    // 배지 테두리 (테마색)
    canvas.drawCircle(
      Offset(badgeX, badgeY),
      badgeR,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = pixelRatio * 1.5,
    );
    // 배지 숫자 (테마색 → 흰 배경 위에서 가독성 최상)
    final numPb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontWeight: ui.FontWeight.w900, fontSize: 9 * pixelRatio),
    )..pushStyle(ui.TextStyle(color: ui.Color(bgColor.toARGB32())))
     ..addText('$number');
    final numPara = numPb.build()..layout(ui.ParagraphConstraints(width: badgeR * 2));
    canvas.drawParagraph(numPara, Offset(badgeX - badgeR, badgeY - numPara.height / 2));
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = bd!.buffer.asUint8List();
  _markerCache[key] = bytes;
  return bytes;
}

Future<Uint8List> _buildLocationBitmap(double pixelRatio) async {
  const logicalSize = 26.0;
  final pxSize = (logicalSize * pixelRatio).roundToDouble();
  final cx = pxSize / 2;
  final cy = pxSize / 2;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, pxSize, pxSize));
  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, pxSize, pxSize)));

  canvas.drawCircle(
    Offset(cx, cy),
    pxSize * 0.46,
    Paint()
      ..color = const Color(0x40007AFF)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, pixelRatio * 4),
  );
  canvas.drawCircle(
    Offset(cx, cy),
    pxSize * 0.33,
    Paint()..color = const Color(0xFF007AFF),
  );
  canvas.drawCircle(
    Offset(cx, cy),
    pxSize * 0.33,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = pixelRatio * 2.5,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.toInt(), pxSize.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

// ─── 화면 ─────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pinManager;
  PointAnnotationManager? _locationManager;
  PointAnnotationManager? _donghaengManager;
  PolylineAnnotationManager? _polylineManager;

  final Map<String, String> _pinAnnotationIds = {};
  final Map<String, (double, double)> _clusterIds = {};
  final Map<String, String> _donghaengAnnotationIds = {}; // annotationId → uid

  double _zoom = 6.5;
  double _cameraCenterLat = 36.5;
  double _cameraCenterLng = 127.5;
  bool _mapReady = false;
  bool _mapInitialized = false;
  // 줌 이벤트 throttle: 마지막으로 업데이트를 트리거한 줌 값
  double _lastUpdateZoom = 6.5;

  // 카메라 위치 저장 디바운스 (1초)
  Timer? _cameraSaveTimer;

  // 지구본 모드
  bool _isGlobeMode = false;
  bool _isGlobeTransitioning = false;
  bool _globePanelExpanded = false;

  // 지구본 전환 핀 모션 오버레이
  bool _showGlobeTransAnim = false;
  bool _globeTransEntering = true;
  List<ClusterItem> _globeTransPins = [];
  double _globeTransZoom = 11.0;
  double _globeTransCenterLat = 37.5665;
  double _globeTransCenterLng = 126.9780;

  Timer? _updateTimer;
  Timer? _cycleTimer;
  Timer? _autoThemeTimer;
  List<PinModel> _currentPins = [];
  Cancelable? _tapSubscription;

  // 클러스터 아이콘 사이클링
  // 키: "${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}"
  final Map<String, int> _clusterIconIndex = {};
  // 라이브 어노테이션 (제자리 업데이트 + 크로스페이드용)
  final Map<String, PointAnnotation> _annotationByKey = {};
  List<_Cluster> _liveClusters = [];
  bool _isCycling = false;
  // 마커 업데이트 뮤텍스 — concurrent deleteAll/createMulti 방지
  bool _isUpdatingMarkers = false;
  // 업데이트 스킵됐을 때 완료 후 재실행할 핀 목록
  List<PinModel>? _pendingUpdatePins;
  // 세대 카운터 — 사이클 도중 _updateMarkers 완료 감지 (isUpdatingMarkers가 false로 돌아온 경우도 잡음)
  int _markerGeneration = 0;
  // 직전 테마 색상 (변경 감지용)
  Color? _lastThemeColor;

  // 경로 모드
  List<PinModel>? _routePins;
  String _routeDate = '';

  // 컨트롤 패널 펼침/접힘
  bool _controlsExpanded = true;
  bool get _routeMode => _routePins != null;

  Timer? _meetingPosTimer; // 이전 화면 좌표 업데이트용 — 현재 미사용 (네이티브 어노테이션으로 대체)

  // 약속 — 네이티브 Mapbox 어노테이션 (지도와 함께 부드럽게 이동)
  PointAnnotationManager? _meetingTargetManager;
  PointAnnotation? _meetingTargetAnnotation;
  PolylineAnnotationManager? _meetingLineManager;
  PolylineAnnotation? _meetingLineAnnotation;
  PointAnnotationManager? _meetingFriendManager;
  PointAnnotation? _meetingFriendAnnotation;

  // 약속 UI 가시성: 앱 시작 시 배너만 노출. 탭 시 바텀시트 슬라이드 업.
  bool _meetingBottomSheetVisible = false;

  // 새싹 애니메이션 오버레이
  PinModel? _sproutPin;
  Offset? _sproutPos;

  // Recap 위치 기반 — GPS 스트림 + 이미 보여준 핀 ID 세트
  // StreamSubscription<dynamic>: geolocator.Position 은 mapbox Position 과 충돌하므로 dynamic 사용
  StreamSubscription<dynamic>? _recapGpsSub;
  final Set<String> _shownRecapIds = {};
  ProximityMemory? _recapBannerPin;

  // 롱프레스 핀 생성 — 1.5초 홀드 후 PinWizardScreen 진입
  Timer? _longPressTimer;
  bool _longPressActive = false;
  Offset? _longPressScreenPos;
  ll.LatLng? _longPressLatLng;

  @override
  void initState() {
    super.initState();
    // CameraPrefs를 미리 로드해 MapWidget cameraOptions에 전달 — (0,0) 기본값 노출 방지
    CameraPrefs.load().then((cam) {
      if (!mounted) return;
      setState(() {
        _zoom = cam.zoom;
        _cameraCenterLat = cam.lat;
        _cameraCenterLng = cam.lng;
        _lastUpdateZoom = cam.zoom;
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _cycleTimer?.cancel();
    _autoThemeTimer?.cancel();
    _meetingPosTimer?.cancel();
    _tapSubscription?.cancel();
    _recapGpsSub?.cancel();
    _cameraSaveTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncMeetingTargetPin() async {
    if (_meetingTargetManager == null) return;
    final ms = ref.read(meetingProvider);
    final meeting = ms.activeMeeting;

    if (meeting == null ||
        !ms.isApproaching ||
        meeting.id.startsWith('demo_')) {
      if (_meetingTargetAnnotation != null) {
        await _meetingTargetManager!.delete(_meetingTargetAnnotation!);
        _meetingTargetAnnotation = null;
      }
      return;
    }

    if (_meetingTargetAnnotation != null) return; // 이미 생성됨

    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final themeColor = ref.read(themePresetProvider).primary;
    final bytes = await _buildMeetingTargetBitmap(
      themeColor: themeColor,
      pixelRatio: pixelRatio,
      avatarUrl: meeting.friendAvatarUrl,
      nickname: meeting.friendNickname,
    );

    if (!mounted) return;
    final annotation = await _meetingTargetManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(meeting.targetLng, meeting.targetLat),
        ),
        image: bytes,
        iconSize: 1.1,
        iconAnchor: IconAnchor.CENTER,
      ),
    );
    _meetingTargetAnnotation = annotation;
  }

  Future<void> _syncMeetingNativeOverlay() async {
    if (_meetingLineManager == null || _meetingFriendManager == null) return;
    final ms = ref.read(meetingProvider);

    // 비활성이면 기존 어노테이션 제거
    if (!ms.isApproaching ||
        ms.activeMeeting == null ||
        ms.activeMeeting!.id.startsWith('demo_')) {
      if (_meetingLineAnnotation != null) {
        await _meetingLineManager!.delete(_meetingLineAnnotation!);
        _meetingLineAnnotation = null;
      }
      if (_meetingFriendAnnotation != null) {
        await _meetingFriendManager!.delete(_meetingFriendAnnotation!);
        _meetingFriendAnnotation = null;
      }
      return;
    }

    final meeting = ms.activeMeeting!;
    final myLat = ms.myLat;
    final myLng = ms.myLng;
    final friendLat = ms.friendLat;
    final friendLng = ms.friendLng;
    final themeColor = ref.read(themePresetProvider).primary;

    // 고무줄 선 — 내 위치와 친구 위치 모두 있을 때만
    if (myLat != null && myLng != null && friendLat != null && friendLng != null) {
      if (_meetingLineAnnotation != null) {
        await _meetingLineManager!.delete(_meetingLineAnnotation!);
        _meetingLineAnnotation = null;
      }
      _meetingLineAnnotation = await _meetingLineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            Position(myLng, myLat),
            Position(friendLng, friendLat),
          ]),
          lineColor: themeColor.toARGB32(),
          lineWidth: 3.5,
          lineOpacity: 0.85,
        ),
      );
    }

    // 친구 현재 위치 핀
    if (friendLat != null && friendLng != null) {
      if (_meetingFriendAnnotation != null) {
        await _meetingFriendManager!.delete(_meetingFriendAnnotation!);
        _meetingFriendAnnotation = null;
      }
      final pixelRatio =
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final bytes = await _buildMeetingTargetBitmap(
        themeColor: themeColor,
        pixelRatio: pixelRatio,
        avatarUrl: meeting.friendAvatarUrl,
        nickname: meeting.friendNickname,
      );
      if (!mounted) return;
      _meetingFriendAnnotation = await _meetingFriendManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(friendLng, friendLat)),
          image: bytes,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }
  }

  // ─── 동행 마커 업데이트 ───────────────────────────────────────────────────

  Future<void> _updateDonghaengMarkers(DonghaengState dongState) async {
    if (_donghaengManager == null) return;
    await _donghaengManager!.deleteAll();
    _donghaengAnnotationIds.clear();

    if (!dongState.isActive) return;
    final session = dongState.session!;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    final participants = session.participants.where((p) =>
      p.lat != null && p.lng != null && !p.arrivedHome).toList();

    if (participants.isEmpty) return;

    final images = await Future.wait(participants.map((p) =>
      _buildDonghaengMarkerBitmap(
        nickname: p.nickname,
        uid: p.uid,
        pixelRatio: pixelRatio,
        themeColor: ref.read(themePresetProvider).primary,
        isMe: p.uid == (session.participants.isNotEmpty ? session.participants.first.uid : ''),
      ),
    ));

    final options = participants.asMap().entries.map((e) =>
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(e.value.lng!, e.value.lat!)),
        image: images[e.key],
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
      ),
    ).toList();

    final created = await _donghaengManager!.createMulti(options);
    for (var i = 0; i < created.length; i++) {
      if (created[i] != null) {
        _donghaengAnnotationIds[created[i]!.id] = participants[i].uid;
      }
    }
  }

  void _startCycleTimer() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted || !_mapReady) return;
      _cycleClusterIcons();
    });
  }

  String _clusterKey(_Cluster c) =>
      '${c.lat.toStringAsFixed(4)}_${c.lng.toStringAsFixed(4)}';

  Future<void> _cycleClusterIcons() async {
    if (_currentPins.isEmpty || _pinManager == null) return;
    if (_isCycling || _annotationByKey.isEmpty) return;
    if (_isUpdatingMarkers || _isGlobeTransitioning || _isGlobeMode) return;

    final clusters = _computeClusters(_currentPins, _isGlobeMode ? 0.0 : _zoom);
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final themeColor = ref.read(themePresetProvider).primary;

    // 아이콘 전환이 필요한 클러스터 수집
    final toCycle = <(PointAnnotation, _Cluster, String, String)>[];
    for (final c in clusters) {
      if (c.countryCode != null || c.pins.length <= 1) continue;
      final shapes = c.pins.map((p) => p.pinShape).toSet().toList()..sort();
      if (shapes.length <= 1) continue;
      final key = _clusterKey(c);
      final annotation = _annotationByKey[key];
      if (annotation == null) continue;
      final oldIdx = (_clusterIconIndex[key] ?? 0) % shapes.length;
      final newIdx = (oldIdx + 1) % shapes.length;
      _clusterIconIndex[key] = newIdx;
      toCycle.add((
        annotation,
        c,
        _shapeSvgPath(shapes[oldIdx]),
        _shapeSvgPath(shapes[newIdx]),
      ));
    }

    if (toCycle.isEmpty) return;

    // 8프레임 크로스페이드 (deleteAll 없이 제자리 update)
    _isCycling = true;
    const frames = 8;
    for (int f = 1; f <= frames; f++) {
      if (!mounted || _pinManager == null || _isUpdatingMarkers) break;
      final progress = f / frames;
      // 비트맵 빌드 전 세대 스냅샷 — 빌드 중 _updateMarkers가 완료돼도 감지
      final genSnapshot = _markerGeneration;
      await Future.wait(toCycle.map((entry) async {
        final (annotation, c, oldSvg, newSvg) = entry;
        final bitmap = await _buildMarkerBitmap(
          isCluster: c.pins.length > 1,
          themeColor: themeColor,
          count: c.pins.length,
          svgPath: newSvg,
          fadeSvgPath: oldSvg,
          fadeProgress: progress,
          pixelRatio: pixelRatio,
        );
        // 세대가 바뀌었거나(_updateMarkers 완료) 업데이트 중이면 스킵
        if (_pinManager == null ||
            _isUpdatingMarkers ||
            _isGlobeTransitioning ||
            _markerGeneration != genSnapshot) { return; }
        annotation.image = bitmap;
        await _pinManager!.update(annotation);
      }));
      if (f < frames) await Future.delayed(const Duration(milliseconds: 45));
    }
    _isCycling = false;
  }

  // ─── 클러스터 계산 ─────────────────────────────────────────────────────────

  List<_Cluster> _computeClusters(List<PinModel> pins, double zoom) {
    // 지구본 줌: 국가별 클러스터
    if (zoom < _kGlobeEnterZoom) {
      final Map<String, List<PinModel>> byCountry = {};
      for (final p in pins) {
        final key = p.countryCode.isEmpty ? '_unknown' : p.countryCode;
        byCountry.putIfAbsent(key, () => []).add(p);
      }
      return byCountry.entries.map((e) {
        final cp = e.value;
        final lat = cp.fold(0.0, (s, p) => s + p.latitude) / cp.length;
        final lng = cp.fold(0.0, (s, p) => s + p.longitude) / cp.length;
        return _Cluster(pins: cp, lat: lat, lng: lng, countryCode: e.key);
      }).toList();
    }

    if (zoom >= 13) {
      return pins
          .map((p) => _Cluster(pins: [p], lat: p.latitude, lng: p.longitude))
          .toList();
    }

    // 반경 기반 클러스터링 — 그리드 경계 없이 가까운 핀끼리 일관되게 합침
    final radius = zoom >= 12
        ? 0.008
        : zoom >= 10
        ? 0.035
        : zoom >= 8
        ? 0.12
        : zoom >= 6
        ? 0.45
        : 1.8;

    final remaining = List<int>.generate(pins.length, (i) => i);
    final clusters = <_Cluster>[];

    while (remaining.isNotEmpty) {
      final seedIdx = remaining.removeAt(0);
      final group = [pins[seedIdx]];
      double cLat = pins[seedIdx].latitude;
      double cLng = pins[seedIdx].longitude;

      bool changed = true;
      while (changed) {
        changed = false;
        for (int i = remaining.length - 1; i >= 0; i--) {
          final p = pins[remaining[i]];
          final d = math.sqrt(
            math.pow(p.latitude - cLat, 2) + math.pow(p.longitude - cLng, 2),
          );
          if (d < radius) {
            group.add(p);
            remaining.removeAt(i);
            cLat = group.fold(0.0, (s, p) => s + p.latitude) / group.length;
            cLng = group.fold(0.0, (s, p) => s + p.longitude) / group.length;
            changed = true;
          }
        }
      }
      clusters.add(_Cluster(pins: group, lat: cLat, lng: cLng));
    }

    return clusters;
  }

  // ─── 전환 오버레이용 ClusterItem 사전 렌더 ────────────────────────────────

  // Uint8List PNG → ui.Image 디코딩
  Future<ui.Image> _pngToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // 현재 표시 중인 클러스터(_liveClusters) → 각각의 비트맵 이미지를 가진 ClusterItem 목록
  Future<List<ClusterItem>> _buildCaptureItemsForClusters(List<_Cluster> clusters) async {
    if (clusters.isEmpty) return [];
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final themePreset = ref.read(themePresetProvider);
    final themeColor = themePreset.primary;

    return Future.wait(clusters.map((c) async {
      Uint8List bytes;
      if (c.countryCode != null) {
        bytes = await _buildCountryMarkerBitmap(
          countryCode: c.countryCode == '_unknown' ? '' : c.countryCode!,
          count: c.pins.length,
          pixelRatio: pixelRatio,
          themeColor: themeColor,
        );
      } else {
        final shapes = c.pins.map((p) => p.pinShape).toSet().toList()..sort();
        String svgPath;
        Color markerColor;
        if (c.pins.length == 1) {
          svgPath = _shapeSvgPath(c.pins.first.pinShape);
          markerColor = AppConstants.categoryColor(c.pins.first.pinShape, themePreset);
        } else {
          final key = _clusterKey(c);
          final idx = (_clusterIconIndex[key] ?? 0) % shapes.length;
          svgPath = _shapeSvgPath(shapes[idx]);
          markerColor = shapes.length == 1
              ? AppConstants.categoryColor(shapes.first, themePreset)
              : themeColor;
        }
        bytes = await _buildMarkerBitmap(
          isCluster: c.pins.length > 1,
          themeColor: markerColor,
          count: c.pins.length,
          svgPath: svgPath,
          pixelRatio: pixelRatio,
        );
      }
      final img = await _pngToUiImage(bytes);
      return ClusterItem(
        lat: c.lat,
        lng: c.lng,
        count: c.pins.length,
        countryCode: c.countryCode,
        renderedImage: img,
      );
    }));
  }

  // 개별 핀 목록 → 단일 핀 이미지를 가진 ClusterItem 목록 (카테고리별 이미지 중복 제거)
  Future<List<ClusterItem>> _buildCaptureItemsForPins(List<PinModel> pins) async {
    if (pins.isEmpty) return [];
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final themePreset = ref.read(themePresetProvider);

    // Phase 1: 카테고리별 고유 bytes 수집 (캐시 덕분에 빠름)
    final Map<String, Uint8List> bytesByKey = {};
    for (final pin in pins) {
      final svgPath = _shapeSvgPath(pin.pinShape);
      final markerColor = AppConstants.categoryColor(pin.pinShape, themePreset);
      final key = '${markerColor.toARGB32()}_$svgPath';
      if (!bytesByKey.containsKey(key)) {
        bytesByKey[key] = await _buildMarkerBitmap(
          isCluster: false,
          themeColor: markerColor,
          count: 1,
          svgPath: svgPath,
          pixelRatio: pixelRatio,
        );
      }
    }

    // Phase 2: 고유 이미지만 디코딩
    final Map<String, ui.Image> imagesByKey = {};
    for (final entry in bytesByKey.entries) {
      imagesByKey[entry.key] = await _pngToUiImage(entry.value);
    }

    // Phase 3: 핀마다 해당 이미지 연결
    return pins.map((pin) {
      final svgPath = _shapeSvgPath(pin.pinShape);
      final markerColor = AppConstants.categoryColor(pin.pinShape, themePreset);
      final key = '${markerColor.toARGB32()}_$svgPath';
      return ClusterItem(
        lat: pin.latitude,
        lng: pin.longitude,
        count: 1,
        renderedImage: imagesByKey[key],
      );
    }).toList();
  }

  // ─── 마커 업데이트 ─────────────────────────────────────────────────────────

  Future<void> _updateMarkers(List<PinModel> pins) async {
    if (!_mapReady || _pinManager == null) return;
    // 동시 실행 방지: 이전 호출이 진행 중이면 완료 후 재실행 예약
    if (_isUpdatingMarkers) {
      _pendingUpdatePins = pins;
      return;
    }
    _pendingUpdatePins = null;
    _isUpdatingMarkers = true;
    _markerGeneration++;
    _lastUpdateZoom = _zoom;
    try {
    _currentPins = pins;
    if (_routeMode) return; // 경로 모드 중엔 마커 재렌더 스킵
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // 테마 색상 변경 감지 → 캐시 무효화
    final themePreset = ref.read(themePresetProvider);
    final themeColor = themePreset.primary;
    if (_lastThemeColor != null && _lastThemeColor != themeColor) {
      _markerCache.clear();
    }
    _lastThemeColor = themeColor;

    // 지구본 모드에서는 zoom 값에 관계없이 항상 국가 클러스터 사용
    final clusters = _computeClusters(pins, _isGlobeMode ? 0.0 : _zoom);

    final images = await Future.wait(
      clusters.map((c) {
        if (c.countryCode != null) {
          // 지구본 모드: 국기 이모지 마커
          return _buildCountryMarkerBitmap(
            countryCode: c.countryCode == '_unknown' ? '' : c.countryCode!,
            count: c.pins.length,
            pixelRatio: pixelRatio,
            themeColor: themeColor,
          );
        }
        // 클러스터 사이클링 아이콘 계산
        String svgPath = '';
        final shapes = c.pins.map((p) => p.pinShape).toSet().toList()..sort();
        if (c.pins.length == 1) {
          svgPath = _shapeSvgPath(c.pins.first.pinShape);
        } else {
          if (shapes.length > 1) {
            final key = '${c.lat.toStringAsFixed(4)}_${c.lng.toStringAsFixed(4)}';
            final idx = (_clusterIconIndex[key] ?? 0) % shapes.length;
            svgPath = _shapeSvgPath(shapes[idx]);
          } else {
            svgPath = _shapeSvgPath(shapes.first);
          }
        }
        // 단일 핀: per-pin 색 우선, 없으면 카테고리 색
        // 클러스터: 단일 카테고리면 카테고리 색, 혼합이면 테마 색
        final isSingle = c.pins.length == 1;
        Color markerColor;
        Color? markerBodyOverride;
        if (isSingle && c.pins.first.pinOuterColor != null) {
          markerColor = Color(c.pins.first.pinOuterColor!);
        } else if (shapes.length == 1) {
          markerColor = AppConstants.categoryColor(shapes.first, themePreset);
        } else {
          markerColor = themeColor;
        }
        if (isSingle && c.pins.first.pinInnerColor != null) {
          markerBodyOverride = Color(c.pins.first.pinInnerColor!);
        }
        return _buildMarkerBitmap(
          isCluster: c.pins.length > 1,
          themeColor: markerColor,
          bodyColorOverride: markerBodyOverride,
          count: c.pins.length,
          svgPath: svgPath,
          pixelRatio: pixelRatio,
        );
      }),
    );

    if (!mounted) return;

    // ── 클러스터 수 동일: 제자리 업데이트 (빈 프레임 방지) ─────────────────
    if (_liveClusters.isNotEmpty &&
        _liveClusters.length == clusters.length &&
        _annotationByKey.isNotEmpty) {
      if (await _tryUpdateInPlace(clusters, images)) {
        await _polylineManager!.deleteAll();
        return;
      }
    }

    // ── 전체 재생성 (fade-out → delete → create invisible → fade-in) ─────────
    final options = List.generate(
      clusters.length,
      (i) => PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(clusters[i].lng, clusters[i].lat),
        ),
        image: images[i],
        iconSize: 1.0,
        iconOpacity: 1.0,
        iconAnchor: IconAnchor.CENTER,
      ),
    );

    // 1. 구 마커 일괄 삭제
    await _pinManager!.deleteAll();
    _pinAnnotationIds.clear();
    _clusterIds.clear();
    _annotationByKey.clear();

    if (options.isEmpty) {
      _liveClusters = clusters;
      await _polylineManager!.deleteAll();
      return;
    }

    // 2. 새 마커 생성 (투명 상태)
    final created = await _pinManager!.createMulti(options);

    for (var i = 0; i < created.length; i++) {
      final annotation = created[i];
      if (annotation == null) continue;
      final id = annotation.id;
      final cluster = clusters[i];
      _annotationByKey[_clusterKey(cluster)] = annotation;
      if (cluster.countryCode != null) {
        _clusterIds[id] = (cluster.lat, cluster.lng);
      } else if (cluster.pins.length == 1) {
        _pinAnnotationIds[id] = cluster.pins.first.id;
      } else {
        _clusterIds[id] = (cluster.lat, cluster.lng);
      }
    }

    _liveClusters = clusters;
    await _polylineManager!.deleteAll();
    } finally {
      _isUpdatingMarkers = false;
      // 업데이트가 스킵됐던 경우 → 지금 즉시 재실행
      final pending = _pendingUpdatePins;
      if (pending != null && mounted) {
        _pendingUpdatePins = null;
        _updateMarkers(pending); // 대기 중인 업데이트 지연 없이 즉시 실행
      }
    }
  }

  // 클러스터 수가 같을 때 어노테이션을 제자리에서 업데이트
  Future<bool> _tryUpdateInPlace(
      List<_Cluster> newClusters, List<Uint8List> images) async {
    final oldList = _liveClusters;
    final usedOld = List.filled(oldList.length, false);
    final pairs = <(int, int)>[]; // (newIdx, oldIdx)

    for (int ni = 0; ni < newClusters.length; ni++) {
      double minDist = double.infinity;
      int bestOld = -1;
      for (int oi = 0; oi < oldList.length; oi++) {
        if (usedOld[oi]) continue;
        final d = (newClusters[ni].lat - oldList[oi].lat).abs() +
            (newClusters[ni].lng - oldList[oi].lng).abs();
        if (d < minDist) {
          minDist = d;
          bestOld = oi;
        }
      }
      if (bestOld == -1) return false;
      usedOld[bestOld] = true;
      pairs.add((ni, bestOld));
    }

    _pinAnnotationIds.clear();
    _clusterIds.clear();
    final newByKey = <String, PointAnnotation>{};

    for (final (ni, oi) in pairs) {
      final oldKey = _clusterKey(oldList[oi]);
      final annotation = _annotationByKey[oldKey];
      if (annotation == null) return false;
      annotation.geometry =
          Point(coordinates: Position(newClusters[ni].lng, newClusters[ni].lat));
      annotation.image = images[ni];
      await _pinManager!.update(annotation);

      final cluster = newClusters[ni];
      newByKey[_clusterKey(cluster)] = annotation;
      final id = annotation.id;
      if (cluster.countryCode != null) {
        _clusterIds[id] = (cluster.lat, cluster.lng);
      } else if (cluster.pins.length == 1) {
        _pinAnnotationIds[id] = cluster.pins.first.id;
      } else {
        _clusterIds[id] = (cluster.lat, cluster.lng);
      }
    }

    _annotationByKey
      ..clear()
      ..addAll(newByKey);
    _liveClusters = newClusters;
    return true;
  }

  void _scheduleUpdate(List<PinModel> pins) {
    _updateTimer?.cancel();
    _updateTimer = Timer(
      const Duration(milliseconds: 300),
      () => _updateMarkers(pins),
    );
  }

  // ─── 현재 위치 ────────────────────────────────────────────────────────────

  Future<void> _moveToCurrentLocation() async {
    HapticFeedback.lightImpact();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    if (_isGlobeMode) {
      // 지구본 모드: 마지막 알려진 위치로 즉시 전환 (GPS 대기 없음)
      final last = await Geolocator.getLastKnownPosition();
      await _exitGlobeMode(
        lat: last?.latitude ?? 37.5665,
        lng: last?.longitude ?? 126.9780,
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1200),
      );

      final pr = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;
      final dot = await _buildLocationBitmap(pr);
      await _locationManager?.deleteAll();
      await _locationManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(pos.longitude, pos.latitude)),
          image: dot,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (_) {}
  }

  // 지구본 모드 팬 핸들러 — Mapbox scrollEnabled: false 상태에서 Flutter가 lat/lng 직접 제어
  // ─── 지구본 모드 ──────────────────────────────────────────────────────────

  Future<void> _enterGlobeMode() async {
    if (_isGlobeMode || _isGlobeTransitioning || _mapboxMap == null) return;
    _isGlobeTransitioning = true;

    HapticFeedback.mediumImpact();

    // Mapbox 어노테이션 즉시 숨김
    await _pinManager?.setIconOpacity(0.0);

    // 현재 클러스터 비트맵을 ui.Image로 사전 렌더 (캐시됨, 이미지 디코딩 시간 동안 Mapbox opacity 적용 완료됨)
    final capturePins = await _buildCaptureItemsForClusters(_liveClusters);
    if (!mounted) return;

    setState(() {
      _globeTransPins = capturePins;
      _globeTransEntering = true;
      _globeTransZoom = _zoom;
      _globeTransCenterLat = _cameraCenterLat;
      _globeTransCenterLng = _cameraCenterLng;
      _showGlobeTransAnim = true;
    });

    final state = await _mapboxMap!.getCameraState();
    _mapboxMap!.flyTo(
      CameraOptions(
        center: state.center,
        zoom: _kGlobeTargetZoom,
        pitch: 0,
        bearing: state.bearing,
      ),
      MapAnimationOptions(duration: 2200),
    );

    // 이미 opacity=0 이므로 시각적 영향 없이 삭제
    await _pinManager?.deleteAll();
    _pinAnnotationIds.clear();
    _clusterIds.clear();
    _annotationByKey.clear();
    _liveClusters = [];

    // 애니메이션 실제 완료까지 대기 (duration + 200ms 여유)
    await Future.delayed(const Duration(milliseconds: 2250));

    if (mounted) {
      ref.read(globeModeProvider.notifier).state = true;

      setState(() {
        _isGlobeMode = true;
        _isGlobeTransitioning = false;
        _globePanelExpanded = false;
      });
      // 새 마커 추가 전 opacity 복원
      await _pinManager?.setIconOpacity(1.0);
      _updateMarkers(ref.read(filteredPinsProvider));
    }
  }

  Future<void> _exitGlobeMode({double? lat, double? lng}) async {
    if (!_isGlobeMode || _isGlobeTransitioning || _mapboxMap == null) return;

    final targetLat = lat ?? 37.5665;
    final targetLng = lng ?? 126.9780;

    // 지구본 모드 마커 즉시 숨김
    await _pinManager?.setIconOpacity(0.0);

    // 복귀 후 보여줄 개별 핀 이미지 사전 렌더 (카테고리별 중복 제거)
    final sourcePins = ref.read(filteredPinsProvider);
    final capturePins = await _buildCaptureItemsForPins(sourcePins);
    if (!mounted) return;

    ref.read(globeModeProvider.notifier).state = false;
    setState(() {
      _isGlobeMode = false;
      _isGlobeTransitioning = true;
      _globeTransPins = capturePins;
      _globeTransEntering = false;
      _globeTransZoom = 11.0;
      _globeTransCenterLat = targetLat;
      _globeTransCenterLng = targetLng;
      _showGlobeTransAnim = true;
    });

    HapticFeedback.mediumImpact();

    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(targetLng, targetLat)),
        zoom: 11.0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 1400),
    );

    // 이미 opacity=0 이므로 시각적 영향 없이 삭제
    await _pinManager?.deleteAll();
    _pinAnnotationIds.clear();
    _clusterIds.clear();
    _annotationByKey.clear();
    _liveClusters = [];

    // 애니메이션 실제 완료까지 대기 (duration + 100ms 여유)
    await Future.delayed(const Duration(milliseconds: 1350));

    if (mounted) {
      setState(() => _isGlobeTransitioning = false);
      // 새 마커 추가 전 opacity 복원
      await _pinManager?.setIconOpacity(1.0);
      _updateMarkers(ref.read(filteredPinsProvider));
    }
  }

  // ─── 경로 모드 ────────────────────────────────────────────────────────────

  void _onPolylineTap() {
    if (_routeMode) {
      _deactivateRoute();
    } else {
      _showRouteDateSheet(context);
    }
  }

  void _showRouteDateSheet(BuildContext ctx) {
    final pins = ref.read(filteredPinsProvider);
    showAppSheet<void>(
      ctx,
      builder: (_) => _RouteDateSheet(
        pins: pins,
        onSelect: (datePins, label) {
          Navigator.of(ctx).pop();
          _activateRoute(datePins, label);
        },
      ),
    );
  }

  Future<void> _activateRoute(List<PinModel> pins, String label) async {
    final sorted = [...pins]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    setState(() {
      _routePins = sorted;
      _routeDate = label;
    });
    await _drawRoute(sorted);
    if (sorted.isEmpty || _mapboxMap == null) return;

    if (sorted.length == 1) {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              sorted.first.longitude,
              sorted.first.latitude,
            ),
          ),
          zoom: _zoom < 12 ? 13.0 : _zoom,
        ),
        MapAnimationOptions(duration: 800),
      );
    } else {
      // 모든 핀이 화면에 들어오도록 bounds fit
      final lats = sorted.map((p) => p.latitude);
      final lngs = sorted.map((p) => p.longitude);
      final minLat = lats.reduce((a, b) => a < b ? a : b);
      final maxLat = lats.reduce((a, b) => a > b ? a : b);
      final minLng = lngs.reduce((a, b) => a < b ? a : b);
      final maxLng = lngs.reduce((a, b) => a > b ? a : b);

      try {
        final camera = await _mapboxMap!.cameraForCoordinateBounds(
          CoordinateBounds(
            southwest: Point(coordinates: Position(minLng, minLat)),
            northeast: Point(coordinates: Position(maxLng, maxLat)),
            infiniteBounds: false,
          ),
          MbxEdgeInsets(
            top: 100,
            left: 60,
            bottom: 360, // 경로 패널 + 네비 바 공간 확보
            right: 60,
          ),
          null,
          null,
          null,
          null,
        );
        await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1200));
      } catch (_) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                (minLng + maxLng) / 2,
                (minLat + maxLat) / 2,
              ),
            ),
            zoom: 11.0,
          ),
          MapAnimationOptions(duration: 1000),
        );
      }
    }
  }

  void _deactivateRoute() {
    setState(() {
      _routePins = null;
      _routeDate = '';
    });
    _updateMarkers(ref.read(filteredPinsProvider));
  }

  Future<void> _drawRoute(List<PinModel> pins) async {
    if (!_mapReady || _pinManager == null) return;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // 경로 색상: 앱 테마 기반 (위성 지도만 흰색, 나머지는 테마 프라이머리)
    final style = ref.read(mapStyleProvider);
    final themeColor = ref.read(themePresetProvider).primary;
    final (lineColorInt, markerBg, markerText, markerBorder) =
        style == MapStyleOption.satellite
            ? (
                const Color(0xFFFFFFFF).toARGB32(),
                Colors.white,
                const Color(0xFF1C1C1E),
                const Color(0xFF1C1C1E),
              )
            : (
                themeColor.toARGB32(),
                themeColor,
                Colors.white,
                Colors.white,
              );

    await _pinManager!.deleteAll();
    await _polylineManager!.deleteAll();
    _pinAnnotationIds.clear();
    _clusterIds.clear();

    if (pins.isEmpty) return;

    // 번호 마커 생성
    final images = await Future.wait(
      pins.asMap().entries.map(
        (e) => _buildNumberedMarkerBitmap(
          e.key + 1,
          pixelRatio,
          bgColor: markerBg,
          textColor: markerText,
          borderColor: markerBorder,
          svgPath: _shapeSvgPath(e.value.pinShape),
        ),
      ),
    );
    final pointOptions = pins
        .asMap()
        .entries
        .map(
          (e) => PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(e.value.longitude, e.value.latitude),
            ),
            image: images[e.key],
            iconSize: 1.0,
            iconAnchor: IconAnchor.CENTER,
          ),
        )
        .toList();
    final created = await _pinManager!.createMulti(pointOptions);
    for (var i = 0; i < created.length; i++) {
      if (created[i] != null) _pinAnnotationIds[created[i]!.id] = pins[i].id;
    }

    // 폴리라인 연결 (실선; 점선은 LineLayer Style API 필요)
    if (pins.length >= 2) {
      await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: pins
                .map((p) => Position(p.longitude, p.latitude))
                .toList(),
          ),
          lineColor: lineColorInt,
          lineWidth: 4.5,
          lineOpacity: 0.9,
        ),
      );
    }
  }

  // ─── + 버튼: 현재 위치에서 핀 생성 ────────────────────────────────────────

  Future<void> _createPinAtCurrentLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PinWizardScreen(
          location: ll.LatLng(pos.latitude, pos.longitude),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('현재 위치를 가져올 수 없어요. 잠시 후 다시 시도해주세요.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── 새싹 애니메이션 ───────────────────────────────────────────────────────

  Future<void> _triggerSproutAnimation(PinModel pin) async {
    final map = _mapboxMap;
    if (map == null) return;

    // 원래 카메라 상태 저장
    final origZoom = _zoom;
    final origLat = _cameraCenterLat;
    final origLng = _cameraCenterLng;

    // 1단계: 핀 위치로 클로즈업
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pin.longitude, pin.latitude)),
        zoom: 14.5,
      ),
      MapAnimationOptions(duration: 800, startDelay: 0),
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    // flyTo 완료 후 정확한 화면 픽셀 좌표 취득
    final sc = await map.pixelForCoordinate(
      Point(coordinates: Position(pin.longitude, pin.latitude)),
    );

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _sproutPin = pin;
      _sproutPos = Offset(sc.x, sc.y);
    });

    // 2단계: 이펙트 피크 대기
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    // 3단계: 줌아웃 — 오버레이 페이드가 이 구간에 겹침
    // ignore: unawaited_futures
    map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(origLng, origLat)),
        zoom: origZoom,
      ),
      MapAnimationOptions(duration: 950, startDelay: 0),
    );

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (mounted) setState(() { _sproutPin = null; _sproutPos = null; });
  }

  // ─── 지도 스타일 변경 ──────────────────────────────────────────────────────

  // 시간 기반 자동 스타일 결정: 07:00~18:59 → standard, 19:00~06:59 → dark
  MapStyleOption _resolveAutoStyle() {
    final h = DateTime.now().hour;
    return (h >= 7 && h < 19) ? MapStyleOption.standard : MapStyleOption.dark;
  }

  void _startAutoThemeTimer() {
    _autoThemeTimer?.cancel();
    // 1분마다 시간 체크 — 시간 경계(07시·19시) 통과 시 스타일 갱신
    _autoThemeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final resolved = _resolveAutoStyle();
      final current = ref.read(mapStyleProvider);
      if (current == MapStyleOption.auto) {
        _applyMapStyle(resolved);
        setState(() {});
      }
    });
  }

  Future<void> _applyMapStyle(MapStyleOption style) async {
    if (_mapboxMap == null) return;
    final effective = style == MapStyleOption.auto ? _resolveAutoStyle() : style;
    final uri = switch (effective) {
      MapStyleOption.standard => MapboxStyles.STANDARD,
      MapStyleOption.satellite => MapboxStyles.SATELLITE_STREETS,
      MapStyleOption.outdoors => MapboxStyles.OUTDOORS,
      MapStyleOption.dark => MapboxStyles.DARK,
      MapStyleOption.light => 'mapbox://styles/mapbox/light-v11',
      MapStyleOption.streets => 'mapbox://styles/mapbox/streets-v12',
      MapStyleOption.buildings3d => 'mapbox://styles/mapbox/streets-v12',
      MapStyleOption.navDay => 'mapbox://styles/mapbox/navigation-day-v1',
      MapStyleOption.navNight => 'mapbox://styles/mapbox/navigation-night-v1',
      MapStyleOption.satellitePure => 'mapbox://styles/mapbox/satellite-v9',
      MapStyleOption.standardSatellite => MapboxStyles.STANDARD_SATELLITE,
      MapStyleOption.auto => MapboxStyles.STANDARD, // unreachable
    };
    await _mapboxMap!.style.setStyleURI(uri);
    if (effective == MapStyleOption.standard) {
      await _mapboxMap!.style.setProjection(
        StyleProjection(name: StyleProjectionName.globe),
      );
    }
  }

  // ─── 지도 탭 핸들러 ──────────────────────────────────────────────────────

  void _onMapTap(MapContentGestureContext ctx) {
    if (_mapboxMap == null || _isGlobeTransitioning) return;

    if (_isGlobeMode) {
      final lat = ctx.point.coordinates.lat.toDouble();
      final lng = ctx.point.coordinates.lng.toDouble();
      _exitGlobeMode(lat: lat, lng: lng);
    }
  }

  // ─── 지도 롱프레스 (1.5s) → 핀 생성 ──────────────────────────────────────

  void _onMapLongTap(MapContentGestureContext ctx) {
    if (_mapboxMap == null || _isGlobeTransitioning || _isGlobeMode) return;
    if (_zoom < 4) return;

    final lat = ctx.point.coordinates.lat.toDouble();
    final lng = ctx.point.coordinates.lng.toDouble();
    final sx = ctx.touchPosition.x.toDouble();
    final sy = ctx.touchPosition.y.toDouble();

    _longPressTimer?.cancel();
    setState(() {
      _longPressActive = true;
      _longPressScreenPos = Offset(sx, sy);
      _longPressLatLng = ll.LatLng(lat, lng);
    });

    // SDK long-tap fires at ~0.5s; we wait 1s more → ~1.5s total
    _longPressTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final loc = _longPressLatLng;
      setState(() {
        _longPressActive = false;
        _longPressScreenPos = null;
        _longPressLatLng = null;
      });
      if (loc != null) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PinWizardScreen(location: loc),
        ));
      }
    });
  }

  // ─── 레이어 시트 ──────────────────────────────────────────────────────────

  void _showFilterModal(BuildContext ctx) {
    showAppSheet<void>(
      ctx,
      builder: (sheetCtx) => FilterSheet(
        onClose: () => Navigator.of(sheetCtx).pop(),
      ),
    );
  }

  void _showMeetingCreateSheet(BuildContext ctx) {
    showAppSheet<void>(
      ctx,
      builder: (_) => const MeetingCreateSheet(),
    );
  }

  void _showFriendsScreen(BuildContext ctx) {
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
    );
  }

  void _showNotificationCenter(BuildContext ctx) {
    showAppSheet<void>(
      ctx,
      builder: (_) => const _NotificationCenterSheet(),
    );
  }

  void _showLayerSheet(BuildContext ctx, WidgetRef ref) {
    showAppSheet<void>(
      ctx,
      builder: (_) => _LayerSheet(
        current: ref.read(mapStyleProvider),
        onSelect: (style) {
          ref.read(mapStyleProvider.notifier).state = style;
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  // ─── 한국어 레이블 적용 ────────────────────────────────────────────────────

  Future<void> _applyKoreanLabels([MapboxMap? map]) async {
    final m = map ?? _mapboxMap;
    if (m == null) return;
    try {
      await m.style.localizeLabels('ko', null);
    } catch (_) {}
    // 3D 건물 모드일 때 FillExtrusionLayer 추가
    if (ref.read(mapStyleProvider) == MapStyleOption.buildings3d) {
      await _apply3DBuildings(m);
    }
  }

  // ─── 3D 건물 익스트루전 레이어 ───────────────────────────────────────────

  Future<void> _apply3DBuildings(MapboxMap m) async {
    const layerId = 'pinlog-3d-buildings';
    try { await m.style.removeStyleLayer(layerId); } catch (_) {}
    try {
      await m.style.addLayer(FillExtrusionLayer(
        id: layerId,
        sourceId: 'composite',
        sourceLayer: 'building',
        fillExtrusionOpacity: 0.72,
        fillExtrusionColor: const Color(0xFFBEC8D8).toARGB32(),
        fillExtrusionAmbientOcclusionIntensity: 0.35,
        fillExtrusionAmbientOcclusionRadius: 3.0,
      ));
      // 건물 데이터 기반 높이 — 줌 15 이상에서 점진적으로 표시
      await m.style.setStyleLayerProperty(
        layerId, 'filter',
        ['==', ['get', 'extrude'], 'true'],
      );
      await m.style.setStyleLayerProperty(
        layerId, 'fill-extrusion-height',
        ['interpolate', ['linear'], ['zoom'], 15, 0, 15.05, ['get', 'height']],
      );
      await m.style.setStyleLayerProperty(
        layerId, 'fill-extrusion-base',
        ['interpolate', ['linear'], ['zoom'], 15, 0, 15.05, ['get', 'min_height']],
      );
    } catch (_) {}
  }

  // ─── 지도 생성 콜백 ───────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // 스플래시 flyTo 종착점과 동일한 카메라로 시작 — 크로스페이드 시 두 맵 뷰가 일치해 전환이 끊기지 않음
    final cam = await CameraPrefs.load();
    _zoom = cam.zoom;
    _cameraCenterLat = cam.lat;
    _cameraCenterLng = cam.lng;
    _lastUpdateZoom = cam.zoom;

    await mapboxMap.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(cam.lng, cam.lat)),
        zoom: cam.zoom,
        pitch: 0,
        bearing: 0,
      ),
    );

    // 거리 스케일바 + 나침반 숨기기 (나침반이 상단 버튼과 겹침)
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

    // 제스처 설정: tilt/rotation 동시 사용 시 끊김 제거
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,
        simultaneousRotateAndPinchToZoomEnabled: true,
        increaseRotateThresholdWhenPinchingToZoom: false,
        increasePinchToZoomThresholdWhenRotating: false,
        rotateDecelerationEnabled: true,
        scrollDecelerationEnabled: true,
      ),
    );

    // Mapbox 기본 위치 표시기 비활성화 (커스텀 blue dot 사용)
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );

    await mapboxMap.style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );

    // 지구본 모드에서 pitch(기울기) 자유 조작 허용 — 기본값(30°)을 80°으로 확장
    await mapboxMap.setBounds(
      CameraBoundsOptions(maxPitch: 80),
    );

    // 초기 스타일 로드 후 한국어 레이블 적용 (mapboxMap 직접 전달 — null 방지)
    await _applyKoreanLabels(mapboxMap);

    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _pinManager = await mapboxMap.annotations.createPointAnnotationManager();
    _locationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _donghaengManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _meetingTargetManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _meetingLineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _meetingFriendManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    _tapSubscription = _pinManager!.tapEvents(
      onTap: (annotation) {
        final pinId = _pinAnnotationIds[annotation.id];
        if (pinId != null) {
          if (_isGlobeMode || _isGlobeTransitioning) return;
          HapticFeedback.lightImpact();
          // showGeneralDialog로 슬라이드+페이드 팝업
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: '',
            barrierColor: Colors.black.withValues(alpha: 0.30),
            transitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (ctx, _, _) => PinDetailSheet(
              pinId: pinId,
              onClose: () => Navigator.of(ctx).pop(),
            ),
            transitionBuilder: (_, anim, _, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            ),
          );
          return;
        }
        final center = _clusterIds[annotation.id];
        if (center != null) {
          HapticFeedback.lightImpact();
          if (_isGlobeMode) {
            _exitGlobeMode(lat: center.$1, lng: center.$2);
            return;
          }
          _mapboxMap?.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(center.$2, center.$1)),
              zoom: _zoom + 2,
            ),
            MapAnimationOptions(duration: 500),
          );
        }
      },
    );

    setState(() {
      _mapReady = true;
      _mapInitialized = true;
    });

    final pins = ref.read(filteredPinsProvider);
    await _updateMarkers(pins);
    _startCycleTimer();
    _startRecapGpsStream();
    await _syncMeetingTargetPin();
  }

  void _startRecapGpsStream() {
    _recapGpsSub?.cancel();
    // geolocator.Position 은 hide 되어 있으므로 dynamic 리스너 사용
    _recapGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 80,
      ),
    ).listen((dynamic pos) => _onRecapPosition(
          (pos.latitude as num).toDouble(),
          (pos.longitude as num).toDouble(),
        ));
  }

  void _onRecapPosition(double lat, double lng) {
    if (!mounted) return;
    if (_recapBannerPin != null) return; // 이미 배너 표시 중

    final allPins = ref.read(pinsProvider);
    final nearby = RecapService.instance.getMemoriesNear(
      allPins,
      lat,
      lng,
      shownIds: _shownRecapIds,
    );
    if (nearby.isEmpty) return;

    final memory = nearby.first;
    _shownRecapIds.add(memory.pin.id);
    setState(() => _recapBannerPin = memory);
  }

  // ─── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allPins = ref.watch(pinsProvider);
    final meetingState = ref.watch(meetingProvider);
    final notifCount = ref.watch(pendingRequestCountProvider);
    final enabledControls = ref.watch(mapControlsProvider);
    final meetingSheetActive = _meetingBottomSheetVisible &&
        meetingState.isApproaching &&
        meetingState.activeMeeting != null &&
        !(meetingState.activeMeeting?.id.startsWith('demo_') ?? false);

    ref.listen(filteredPinsProvider, (_, pins) {
      _scheduleUpdate(pins);
    });

    ref.listen(triggerCreatePinProvider, (_, triggered) {
      if (triggered) {
        ref.read(triggerCreatePinProvider.notifier).state = false;
        _createPinAtCurrentLocation();
      }
    });

    ref.listen(newlyCreatedPinProvider, (_, pin) {
      if (pin == null) return;
      ref.read(newlyCreatedPinProvider.notifier).state = null;
      _triggerSproutAnimation(pin);
    });

    ref.listen(mapStyleProvider, (prev, next) {
      if (prev == next) return;
      _applyMapStyle(next);
      if (next == MapStyleOption.auto) {
        _startAutoThemeTimer();
      } else {
        _autoThemeTimer?.cancel();
      }
    });

    ref.listen(themePresetProvider, (prev, next) {
      if (prev != next) {
        _markerCache.clear();
        _scheduleUpdate(_currentPins);
      }
    });

    // 동행 세션 → 마커 업데이트
    ref.listen(donghaengProvider, (prev, next) {
      if (next.session != prev?.session ||
          next.myLat != prev?.myLat ||
          next.myLng != prev?.myLng) {
        _updateDonghaengMarkers(next);
      }
    });

    // 약속 위치 업데이트 → 네이티브 어노테이션 동기화
    ref.listen(meetingProvider, (prev, next) {
      // 미팅 ID 변경 시 시트 리셋
      if (prev?.activeMeeting?.id != next.activeMeeting?.id) {
        if (mounted) setState(() => _meetingBottomSheetVisible = false);
      }
      // approaching 상태 진입 시 바텀시트 자동 오픈
      if (prev?.isApproaching == false && next.isApproaching) {
        if (mounted) setState(() => _meetingBottomSheetVisible = true);
      }
      // 약속 활성화/비활성화 시 네이티브 타깃 핀 + 오버레이 동기화
      if (prev?.isApproaching != next.isApproaching ||
          prev?.activeMeeting?.id != next.activeMeeting?.id) {
        _syncMeetingTargetPin();
        _syncMeetingNativeOverlay();
      }
      // 내/친구 위치 변경 시 네이티브 오버레이 갱신
      if (next.isApproaching &&
          next.activeMeeting?.id.startsWith('demo_') != true &&
          (prev?.myLat != next.myLat ||
              prev?.friendLat != next.friendLat ||
              prev?.friendLng != next.friendLng)) {
        _syncMeetingNativeOverlay();
      }
    });

    final currentStyle = ref.watch(mapStyleProvider);
    final effectiveStyle = currentStyle == MapStyleOption.auto
        ? _resolveAutoStyle()
        : currentStyle;
    final styleUri = switch (effectiveStyle) {
      MapStyleOption.standard => MapboxStyles.STANDARD,
      MapStyleOption.satellite => MapboxStyles.SATELLITE_STREETS,
      MapStyleOption.outdoors => MapboxStyles.OUTDOORS,
      MapStyleOption.dark => MapboxStyles.DARK,
      MapStyleOption.light => 'mapbox://styles/mapbox/light-v11',
      MapStyleOption.streets => 'mapbox://styles/mapbox/streets-v12',
      MapStyleOption.buildings3d => 'mapbox://styles/mapbox/streets-v12',
      MapStyleOption.navDay => 'mapbox://styles/mapbox/navigation-day-v1',
      MapStyleOption.navNight => 'mapbox://styles/mapbox/navigation-night-v1',
      MapStyleOption.satellitePure => 'mapbox://styles/mapbox/satellite-v9',
      MapStyleOption.standardSatellite => MapboxStyles.STANDARD_SATELLITE,
      MapStyleOption.auto => MapboxStyles.STANDARD, // unreachable
    };

    final bool controlsVisible = _mapInitialized && !_isGlobeMode && !_isGlobeTransitioning;

    final isDarkStatusBar = _isGlobeMode ||
        _isGlobeTransitioning ||
        effectiveStyle == MapStyleOption.dark ||
        effectiveStyle == MapStyleOption.satellite ||
        effectiveStyle == MapStyleOption.navNight ||
        effectiveStyle == MapStyleOption.satellitePure ||
        effectiveStyle == MapStyleOption.standardSatellite;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDarkStatusBar
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF050B1A),
        body: Stack(
          children: [
            // ── Mapbox 지도 ───────────────────────────────────────────────
            MapWidget(
              styleUri: styleUri,
              onStyleLoadedListener: (_) => _applyKoreanLabels(_mapboxMap),
              onMapCreated: _onMapCreated,
              onCameraChangeListener: (data) {
                if (!_mapInitialized) return;
                final newZoom = data.cameraState.zoom;
                final center = data.cameraState.center.coordinates;
                _cameraCenterLat = center.lat.toDouble();
                _cameraCenterLng = center.lng.toDouble();

                // 전환 중엔 마커 업데이트 없이 zoom 값만 갱신
                if (_isGlobeTransitioning) {
                  _zoom = newZoom;
                  return;
                }
                if ((newZoom - _zoom).abs() > 0.08) {
                  setState(() => _zoom = newZoom);
                  // 클러스터 경계(정수 줌)를 넘어설 때만 업데이트 스케줄
                  // — 사소한 줌 변화로 인한 불필요한 deleteAll/createMulti 방지
                  final crossedBoundary =
                      (newZoom.floor() != _lastUpdateZoom.floor()) ||
                      (newZoom - _lastUpdateZoom).abs() >= 1.0;
                  if (crossedBoundary || _annotationByKey.isEmpty) {
                    _lastUpdateZoom = newZoom;
                    _scheduleUpdate(
                      _currentPins.isEmpty
                          ? ref.read(filteredPinsProvider)
                          : _currentPins,
                    );
                  }
                }
                // 줌 기반 지구본 모드 자동 전환
                if (!_isGlobeMode && newZoom < _kGlobeEnterZoom) {
                  _enterGlobeMode();
                } else if (_isGlobeMode && newZoom > _kGlobeExitZoom) {
                  _exitGlobeMode();
                }

                // 1초 디바운스 후 카메라 위치 저장 (스플래시 복원용)
                if (!_isGlobeMode && !_isGlobeTransitioning) {
                  _cameraSaveTimer?.cancel();
                  _cameraSaveTimer = Timer(const Duration(seconds: 1), () {
                    CameraPrefs.save(
                      lat: _cameraCenterLat,
                      lng: _cameraCenterLng,
                      zoom: _zoom,
                    );
                  });
                }
              },
              onTapListener: _onMapTap, // ignore: deprecated_member_use
              onLongTapListener: _onMapLongTap, // ignore: deprecated_member_use
            ),

            // ── 지도 컨트롤 (왼쪽 상단) ──────────────────────────────────
            Positioned(
              left: 0,
              top: 0,
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 280),
                child: IgnorePointer(
                  ignoring: !controlsVisible,
                  child: _MapControls(
                    onGlobeTap: _enterGlobeMode,
                    onLayerTap: () => _showLayerSheet(context, ref),
                    onFilterTap: () => _showFilterModal(context),
                    onPolylineTap: _onPolylineTap,
                    onNotifTap: () => _showNotificationCenter(context),
                    notifCount: notifCount,
                    onMeetingTap: () {
                      if (meetingState.isApproaching &&
                          meetingState.activeMeeting != null &&
                          !meetingState.activeMeeting!.id.startsWith('demo_')) {
                        setState(() => _meetingBottomSheetVisible = !_meetingBottomSheetVisible);
                      } else {
                        _showMeetingCreateSheet(context);
                      }
                    },
                    onFriendsTap: () => _showFriendsScreen(context),
                    routeActive: _routeMode,
                    isExpanded: _controlsExpanded,
                    enabledControls: enabledControls,
                    onToggle: () =>
                        setState(() => _controlsExpanded = !_controlsExpanded),
                  ),
                ),
              ),
            ),

            // ── 현재 위치 버튼 (우측 하단, 약속 시트 있으면 위로 이동) ───
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: meetingSheetActive
                  ? MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0) + 89 + 205
                  : MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0) + 89,
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 280),
                child: IgnorePointer(
                  ignoring: !controlsVisible,
                  child: GestureDetector(
                    onTap: _moveToCurrentLocation,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 22,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 지구본 모드: 하단 패널 (nav bar는 main_shell에서 숨김) ────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_isGlobeMode,
                child: AnimatedOpacity(
                  opacity: _isGlobeMode ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: _GlobeBottomPanel(
                    pinCount: allPins.length,
                    isExpanded: _globePanelExpanded,
                    onExitGlobeMode: _exitGlobeMode,
                    onGoToCurrentLocation: _moveToCurrentLocation,
                    onToggle: () => setState(
                      () => _globePanelExpanded = !_globePanelExpanded,
                    ),
                  ),
                ),
              ),
            ),

            // ── Nebulous 클러스터 애니메이션 오버레이 ──────────────────────
            // ── 지구본 ↔ 지도 전환 핀 모션 오버레이 ─────────────────────
            if (_showGlobeTransAnim)
              Positioned.fill(
                child: GlobeTransitionOverlay(
                  pins: _globeTransPins,
                  zoom: _globeTransZoom,
                  centerLat: _globeTransCenterLat,
                  centerLng: _globeTransCenterLng,
                  themeColor: ref.read(themePresetProvider).primary,
                  entering: _globeTransEntering,
                  onDone: () {
                    if (mounted) setState(() => _showGlobeTransAnim = false);
                  },
                ),
              ),

            // ── 약속 바텀시트 (지도 어노테이션은 네이티브로 처리됨) ─────────
            Builder(builder: (ctx) {
              if (!meetingState.isApproaching ||
                  meetingState.activeMeeting == null ||
                  meetingState.activeMeeting!.id.startsWith('demo_')) {
                return const SizedBox.shrink();
              }
              final bottomInset = MediaQuery.of(ctx).padding.bottom;
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: _meetingBottomSheetVisible
                    ? bottomInset + 72 + 8
                    : -220.0,
                child: MeetingBottomSheet(
                  onClose: () => setState(
                    () => _meetingBottomSheetVisible = false,
                  ),
                ),
              );
            }),

            // ── 경로 패널 (플로팅 카드, 네비게이션 바 위에 위치) ──────────
            if (_routeMode)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0) + 89,
                child: _RoutePanel(
                  pins: _routePins!,
                  dateLabel: _routeDate,
                  onClose: _deactivateRoute,
                  onSave: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('동선이 저장되었어요'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      duration: const Duration(seconds: 2),
                    ),
                  ),
                ),
              ),

            // ── 동행 세션 패널 ────────────────────────────────────────────
            const DonghaengSessionPanel(),

            // ── Recap 위치 배너 ───────────────────────────────────────────
            if (_recapBannerPin != null)
              RecapLocationBanner(
                memory: _recapBannerPin!,
                onDismiss: () => setState(() => _recapBannerPin = null),
              ),

            // ── 새싹 애니메이션 오버레이 ──────────────────────────────────
            if (_sproutPin != null && _sproutPos != null)
              _PinSproutOverlay(
                key: ValueKey(_sproutPin!.id),
                pin: _sproutPin!,
                screenPos: _sproutPos!,
                themeColor: ref.read(themePresetProvider).primary,
              ),

            // ── 롱프레스 리플 오버레이 ────────────────────────────────────
            if (_longPressActive && _longPressScreenPos != null)
              Positioned(
                left: _longPressScreenPos!.dx - 45,
                top: _longPressScreenPos!.dy - 45,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_longPressScreenPos),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    builder: (ctx2, t, child) => CustomPaint(
                      size: const Size(90, 90),
                      painter: _LongPressRipplePainter(
                        progress: t,
                        color: ref.read(themePresetProvider).primary,
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

// ─── 지도 컨트롤 ──────────────────────────────────────────────────────────────

class _MapControls extends StatelessWidget {
  final VoidCallback onGlobeTap;
  final VoidCallback onLayerTap;
  final VoidCallback onFilterTap;
  final VoidCallback onPolylineTap;
  final VoidCallback onToggle;
  final VoidCallback onMeetingTap;
  final VoidCallback onFriendsTap;
  final VoidCallback onNotifTap;
  final bool routeActive;
  final bool isExpanded;
  final int notifCount;
  final Set<MapControlId> enabledControls;

  const _MapControls({
    required this.onGlobeTap,
    required this.onLayerTap,
    required this.onFilterTap,
    required this.onPolylineTap,
    required this.onToggle,
    required this.onMeetingTap,
    required this.onFriendsTap,
    required this.onNotifTap,
    required this.enabledControls,
    this.routeActive = false,
    this.isExpanded = true,
    this.notifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    // 화면 너비 - 좌측 패딩 - 우측 여백 - 두 고정 버튼(44+8+44+8) = 확장 영역 최대 너비
    final maxExpandWidth = MediaQuery.of(context).size.width - 16 - 16 - 44 - 8 - 44 - 8;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 알림 버튼 (항상 고정 앵커) ────────────────────────────
            GestureDetector(
              onTap: onNotifTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: notifCount > 0
                              ? context.primaryColor.withValues(alpha: 0.15)
                              : context.glassBtnBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: notifCount > 0
                                ? context.primaryColor.withValues(alpha: 0.40)
                                : context.glassBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            () {
                              if (notifCount > 0) {
                                return isDark
                                    ? 'lib/img/notification-on-svgrepo-com (1).svg'
                                    : 'lib/img/notification-on-svgrepo-com.svg';
                              } else {
                                return isDark
                                    ? 'lib/img/notification-bell-svgrepo-com (2).svg'
                                    : 'lib/img/notification-bell-svgrepo-com.svg';
                              }
                            }(),
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              notifCount > 0
                                  ? context.primaryColor
                                  : context.labelColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      if (notifCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                notifCount > 9 ? '9+' : '$notifCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── 토글 버튼 (펼침/접힘 ▶/◀) ────────────────────────────
            GestureDetector(
              onTap: onToggle,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.glassBtnBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: context.labelColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 펼침: 오른쪽으로 수평 확장, 넘치면 스크롤 ────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                opacity: isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: isExpanded
                    ? SizedBox(
                        width: maxExpandWidth.clamp(44.0, double.infinity),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              if (enabledControls.contains(MapControlId.filter)) ...[
                                GlassButton(icon: Icons.tune, onTap: onFilterTap, size: 44),
                                const SizedBox(width: 8),
                              ],
                              if (enabledControls.contains(MapControlId.globe)) ...[
                                GlassButton(icon: Icons.public_rounded, onTap: onGlobeTap, size: 44),
                                const SizedBox(width: 8),
                              ],
                              if (enabledControls.contains(MapControlId.layer)) ...[
                                GlassButton(icon: Icons.layers_outlined, onTap: onLayerTap, size: 44),
                                const SizedBox(width: 8),
                              ],
                              if (enabledControls.contains(MapControlId.route)) ...[
                                GestureDetector(
                                  onTap: onPolylineTap,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: routeActive
                                          ? context.primaryColor
                                          : context.glassBtnBg,
                                      shape: BoxShape.circle,
                                      border: routeActive
                                          ? null
                                          : Border.all(color: context.glassBorder),
                                      boxShadow: [
                                        BoxShadow(
                                          color: routeActive
                                              ? context.primaryColor.withValues(alpha: 0.4)
                                              : Colors.black.withValues(alpha: 0.08),
                                          blurRadius: routeActive ? 14 : 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      routeActive ? Icons.close_rounded : Icons.route_rounded,
                                      size: 20,
                                      color: routeActive ? Colors.white : context.labelColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (enabledControls.any((id) => id == MapControlId.meeting || id == MapControlId.friends) &&
                                  enabledControls.any((id) => id == MapControlId.filter || id == MapControlId.globe || id == MapControlId.layer || id == MapControlId.route)) ...[
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (enabledControls.contains(MapControlId.meeting)) ...[
                                GlassButton(icon: Icons.event_rounded, onTap: onMeetingTap, size: 44),
                                const SizedBox(width: 8),
                              ],
                              if (enabledControls.contains(MapControlId.friends)) ...[
                                GlassButton(icon: Icons.people_rounded, onTap: onFriendsTap, size: 44),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 지구본 모드 하단 패널 (슬라이드로 펼치기) ──────────────────────────────

class _GlobeBottomPanel extends StatelessWidget {
  final int pinCount;
  final bool isExpanded;
  final VoidCallback onExitGlobeMode;
  final VoidCallback onGoToCurrentLocation;
  final VoidCallback onToggle;

  const _GlobeBottomPanel({
    required this.pinCount,
    required this.isExpanded,
    required this.onExitGlobeMode,
    required this.onGoToCurrentLocation,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom =
        MediaQuery.of(context).viewPadding.bottom.clamp(0.0, 40.0);
    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200 && !isExpanded) onToggle();
        if (v > 200 && isExpanded) onToggle(); // 아래로 스와이프 → 접음
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF080816).withValues(alpha: 0.88),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(24, 14, 24, safeBottom + 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 드래그 핸들
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ── 펼쳐졌을 때만 보이는 내용 ──
                  if (isExpanded) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'lib/img/place/map-pin.svg',
                              width: 20, height: 20,
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pinCount개의 기억',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '지도 위에 새겨진 당신의 이야기',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ] else
                    const SizedBox(height: 12),

                  // ── 버튼 행 (항상 표시) ──
                  Row(
                    children: [
                      _GlobePanelButton(
                        icon: Icons.my_location_rounded,
                        label: '현재 위치',
                        onTap: onGoToCurrentLocation,
                        isPrimary: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GlobePanelButton(
                          icon: Icons.map_rounded,
                          label: '지도 보기',
                          onTap: onExitGlobeMode,
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),

                  // ── 힌트 (펼쳤을 때만) ──
                  if (isExpanded) ...[
                    const SizedBox(height: 14),
                    Text(
                      '탭해서 확대  ·  핀치로 탐색',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 지구본 패널 버튼 ─────────────────────────────────────────────────────────

class _GlobePanelButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _GlobePanelButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  State<_GlobePanelButton> createState() => _GlobePanelButtonState();
}

class _GlobePanelButtonState extends State<_GlobePanelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isPrimary
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isPrimary ? AppColors.dark : Colors.white,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isPrimary ? AppColors.dark : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 경로 날짜 선택 시트 ──────────────────────────────────────────────────────

class _RouteDateSheet extends StatelessWidget {
  final List<PinModel> pins;
  final void Function(List<PinModel> pins, String label) onSelect;

  const _RouteDateSheet({required this.pins, required this.onSelect});

  // 날짜별 그루핑 (최신순)
  List<(String key, String label, List<PinModel> datePins)> _grouped() {
    final Map<String, List<PinModel>> byDate = {};
    for (final p in pins) {
      final k =
          '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(k, () => []).add(p);
    }
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return byDate.entries.map((e) {
      final d = DateTime.parse(e.key);
      final label = '${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
      return (e.key, label, e.value);
    }).toList()..sort((a, b) => b.$1.compareTo(a.$1));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    final bottomInset = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);

    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: context.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '날짜별 경로 보기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.labelColor,
                  ),
                ),
                const Spacer(),
                Icon(Icons.route_rounded, size: 18, color: context.primaryColor),
              ],
            ),
          ),
          const Divider(height: 1),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '핀이 없어요',
                style: TextStyle(color: context.subLabelColor),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (context, i) {
                  final (_, label, datePins) = groups[i];
                  final sorted = [...datePins]
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  return GestureDetector(
                    onTap: () => onSelect(sorted, label),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: context.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.labelColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${datePins.length}개',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.subLabelColor,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: bottomInset + 8),
        ],
      ),
    );
  }
}

// ─── 경로 플로팅 카드 ─────────────────────────────────────────────────────────

class _RoutePanel extends StatelessWidget {
  final List<PinModel> pins;
  final String dateLabel;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const _RoutePanel({
    required this.pins,
    required this.dateLabel,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 날짜 + 핀 수 + 닫기
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.route_rounded,
                    size: 15,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.labelColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${pins.length}개 장소',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.subLabelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: context.subLabelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 구분선
          Divider(height: 1, color: context.glassBorder),
          const SizedBox(height: 8),

          // 핀 목록 (최대 4줄, 스크롤 가능)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: pins.length,
              itemBuilder: (context, i) {
                final pin = pins[i];
                final isLast = i == pins.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                  child: Row(
                    children: [
                      // 번호 + 연결선
                      SizedBox(
                        width: 22,
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: context.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pin.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.labelColor,
                          ),
                        ),
                      ),
                      Text(
                        '${pin.createdAt.hour.toString().padLeft(2, '0')}:${pin.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.subLabelColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 저장 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.primaryColor.withValues(alpha: 0.85), context.primaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '이 동선 저장하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 지도 레이어 선택 시트 ────────────────────────────────────────────────────

class _LayerSheet extends StatelessWidget {
  final MapStyleOption current;
  final void Function(MapStyleOption) onSelect;

  const _LayerSheet({required this.current, required this.onSelect});

  static const _options = [
    (MapStyleOption.auto,     '자동',    '시간 기반',   Color(0xFF8B6CF6), Color(0xFF1A1A2E)),
    (MapStyleOption.standard, '기본',    '표준 지도',   Color(0xFF2C3E2A), Color(0xFFEDE3CF)),
    (MapStyleOption.dark,     '다크',    '야간 모드',   Color(0xFFCBBFFF), Color(0xFF0D1220)),
    (MapStyleOption.satellite,'위성',    '항공 사진',   Color(0xFF90EFA0), Color(0xFF1D3D28)),
    (MapStyleOption.outdoors, '야외',    '등산·하이킹', Color(0xFF5A3A18), Color(0xFFF2E8CC)),
    (MapStyleOption.light,        '라이트',   '밝은 모드',    Color(0xFF5C5242), Color(0xFFF6F3EC)),
    (MapStyleOption.streets,      '스트리트', '도로 중심',    Color(0xFF1E2C3A), Color(0xFFFAFAF6)),
    (MapStyleOption.buildings3d,  '3D 도시',  '입체 건물',    Color(0xFFE2E8F0), Color(0xFF1E293B)),
    (MapStyleOption.navDay,          '내비 낮',   '네비게이션 낮',  Color(0xFFFFFFFF), Color(0xFF1E6FF0)),
    (MapStyleOption.navNight,        '내비 밤',   '네비게이션 밤',  Color(0xFF6BBBFF), Color(0xFF1A2533)),
    (MapStyleOption.satellitePure,   '순수 위성', '레이블 없음',    Color(0xFF4ADE80), Color(0xFF1C3A1C)),
    (MapStyleOption.standardSatellite,'위성 3D',  '위성+입체 건물', Color(0xFFAFC2D4), Color(0xFF1C3A1C)),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);
    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: context.handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '지도 스타일',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.labelColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '마음에 드는 스타일을 선택하세요',
              style: TextStyle(fontSize: 13, color: context.subLabelColor),
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: _options.map((opt) {
              final (style, name, desc, textColor, overlayBg) = opt;
              final isActive = current == style;
              return GestureDetector(
                onTap: () => onSelect(style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive
                          ? context.primaryColor
                          : context.glassBorder,
                      width: isActive ? 2.5 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: context.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      children: [
                        // 지도 스타일 일러스트 썸네일
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MapStylePainter(style),
                          ),
                        ),
                        // 텍스트 영역
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  overlayBg.withValues(alpha: 0.0),
                                  overlayBg.withValues(alpha: 0.96),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor.withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 활성 체크
                        if (isActive)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: context.primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: context.primaryColor.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MapStylePainter extends CustomPainter {
  final MapStyleOption style;
  const _MapStylePainter(this.style);

  @override
  void paint(Canvas canvas, Size s) {
    switch (style) {
      case MapStyleOption.standard:
        _paintStandard(canvas, s);
      case MapStyleOption.dark:
        _paintDark(canvas, s);
      case MapStyleOption.satellite:
        _paintSatellite(canvas, s);
      case MapStyleOption.outdoors:
        _paintOutdoors(canvas, s);
      case MapStyleOption.light:
        _paintLight(canvas, s);
      case MapStyleOption.streets:
        _paintStreets(canvas, s);
      case MapStyleOption.buildings3d:
        _paintBuildings3d(canvas, s);
      case MapStyleOption.navDay:
        _paintNavDay(canvas, s);
      case MapStyleOption.navNight:
        _paintNavNight(canvas, s);
      case MapStyleOption.satellitePure:
        _paintSatellitePure(canvas, s);
      case MapStyleOption.standardSatellite:
        _paintStandardSatellite(canvas, s);
      case MapStyleOption.auto:
        _paintAuto(canvas, s);
    }
  }

  void _paintStandard(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFEDE3CF));

    canvas.drawOval(
      Rect.fromLTWH(-s.width * 0.08, s.height * 0.50, s.width * 0.48, s.height * 0.65),
      Paint()..color = const Color(0xFFADD8F0),
    );

    final parkPaint = Paint()..color = const Color(0xFF9FC98B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.54, s.height * 0.14, s.width * 0.30, s.height * 0.24), const Radius.circular(4)),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.10, s.height * 0.28, s.width * 0.16, s.height * 0.12), const Radius.circular(3)),
      Paint()..color = const Color(0xFFA8D494),
    );

    final blockPaint = Paint()..color = const Color(0xFFD8CAAC);
    for (final r in [
      Rect.fromLTWH(s.width * 0.34, s.height * 0.11, s.width * 0.14, s.height * 0.09),
      Rect.fromLTWH(s.width * 0.18, s.height * 0.46, s.width * 0.14, s.height * 0.09),
      Rect.fromLTWH(s.width * 0.62, s.height * 0.44, s.width * 0.16, s.height * 0.08),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), blockPaint);
    }

    canvas.drawLine(Offset(0, s.height * 0.38), Offset(s.width, s.height * 0.52),
        Paint()..color = Colors.white..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.42, 0), Offset(s.width * 0.55, s.height),
        Paint()..color = Colors.white..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(0, s.height * 0.63), Offset(s.width, s.height * 0.68),
        Paint()..color = Colors.white..strokeWidth = 1.5..strokeCap = StrokeCap.round);
  }

  void _paintDark(Canvas canvas, Size s) {
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D1220), Color(0xFF141828)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, 200, 200));
    canvas.drawRect(Offset.zero & s, bg);

    final blockPaint = Paint()..color = const Color(0xFF1E2840);
    for (final r in [
      Rect.fromLTWH(s.width * 0.06, s.height * 0.10, s.width * 0.22, s.height * 0.14),
      Rect.fromLTWH(s.width * 0.34, s.height * 0.08, s.width * 0.18, s.height * 0.11),
      Rect.fromLTWH(s.width * 0.60, s.height * 0.12, s.width * 0.28, s.height * 0.16),
      Rect.fromLTWH(s.width * 0.08, s.height * 0.40, s.width * 0.24, s.height * 0.18),
      Rect.fromLTWH(s.width * 0.50, s.height * 0.38, s.width * 0.20, s.height * 0.13),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), blockPaint);
    }

    canvas.drawLine(Offset(0, s.height * 0.42), Offset(s.width, s.height * 0.50),
        Paint()..color = const Color(0xFF7C5FE8).withValues(alpha: 0.28)..strokeWidth = 8..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawLine(Offset(0, s.height * 0.42), Offset(s.width, s.height * 0.50),
        Paint()..color = const Color(0xFF9B7FFF)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.38, 0), Offset(s.width * 0.45, s.height),
        Paint()..color = const Color(0xFF4ECDC4).withValues(alpha: 0.45)..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(0, s.height * 0.65), Offset(s.width, s.height * 0.60),
        Paint()..color = const Color(0xFF4ECDC4).withValues(alpha: 0.28)..strokeWidth = 1.2..strokeCap = StrokeCap.round);

    for (final (x, y, c) in [
      (0.28, 0.30, const Color(0xFFFF6B9D)),
      (0.65, 0.26, const Color(0xFF7CDDFF)),
      (0.52, 0.56, const Color(0xFFFFD166)),
    ]) {
      canvas.drawCircle(Offset(s.width * x, s.height * y), 4,
          Paint()..color = c.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(Offset(s.width * x, s.height * y), 2, Paint()..color = c);
    }
  }

  void _paintSatellite(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1D3D28));

    for (final (rect, color) in [
      (Rect.fromLTWH(0, 0, s.width * 0.55, s.height * 0.50), const Color(0xFF163020)),
      (Rect.fromLTWH(s.width * 0.40, s.height * 0.45, s.width * 0.60, s.height * 0.55), const Color(0xFF254035)),
      (Rect.fromLTWH(s.width * 0.10, s.height * 0.60, s.width * 0.35, s.height * 0.40), const Color(0xFF2A4A35)),
    ]) {
      canvas.drawPath(Path()..addOval(rect), Paint()..color = color);
    }

    final urbanPaint = Paint()..color = const Color(0xFF3A4A42);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.35, s.height * 0.14, s.width * 0.30, s.height * 0.28), urbanPaint);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.55, s.height * 0.48, s.width * 0.20, s.height * 0.18), urbanPaint);

    final bldPaint = Paint()..color = const Color(0xFF5A6E60);
    for (final r in [
      Rect.fromLTWH(s.width * 0.37, s.height * 0.17, s.width * 0.08, s.height * 0.07),
      Rect.fromLTWH(s.width * 0.48, s.height * 0.20, s.width * 0.10, s.height * 0.06),
      Rect.fromLTWH(s.width * 0.42, s.height * 0.28, s.width * 0.12, s.height * 0.08),
      Rect.fromLTWH(s.width * 0.57, s.height * 0.50, s.width * 0.09, s.height * 0.07),
    ]) {
      canvas.drawRect(r, bldPaint);
    }

    canvas.drawLine(Offset(0, s.height * 0.44), Offset(s.width, s.height * 0.48),
        Paint()..color = Colors.white.withValues(alpha: 0.55)..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.50, 0), Offset(s.width * 0.52, s.height),
        Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1.0..strokeCap = StrokeCap.round);
  }

  void _paintOutdoors(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF2E8CC));

    final hillPath = Path()
      ..moveTo(s.width * 0.45, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height * 0.55)
      ..quadraticBezierTo(s.width * 0.70, s.height * 0.30, s.width * 0.45, 0)
      ..close();
    canvas.drawPath(hillPath, Paint()..color = const Color(0xFF8FBF6E));

    for (final (offset, alpha) in [
      (0.20, 0.40),
      (0.32, 0.50),
      (0.44, 0.60),
      (0.56, 0.70),
    ]) {
      final path = Path()
        ..moveTo(0, s.height * (offset + 0.04))
        ..cubicTo(s.width * 0.25, s.height * (offset - 0.05), s.width * 0.65, s.height * (offset + 0.07), s.width, s.height * (offset + 0.02));
      canvas.drawPath(path, Paint()..color = const Color(0xFFC4935A).withValues(alpha: alpha)..strokeWidth = 1.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    final trailPath = Path()
      ..moveTo(s.width * 0.15, s.height * 0.72)
      ..quadraticBezierTo(s.width * 0.40, s.height * 0.50, s.width * 0.68, s.height * 0.30)
      ..quadraticBezierTo(s.width * 0.82, s.height * 0.18, s.width * 0.90, s.height * 0.08);
    canvas.drawPath(trailPath, Paint()..color = const Color(0xFFE07B3A)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    final streamPath = Path()
      ..moveTo(0, s.height * 0.55)
      ..quadraticBezierTo(s.width * 0.25, s.height * 0.58, s.width * 0.40, s.height * 0.72)
      ..quadraticBezierTo(s.width * 0.55, s.height * 0.86, s.width * 0.60, s.height);
    canvas.drawPath(streamPath, Paint()..color = const Color(0xFF6BAED6)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  void _paintLight(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF6F3EC));

    canvas.drawOval(
      Rect.fromLTWH(-s.width * 0.04, s.height * 0.54, s.width * 0.44, s.height * 0.55),
      Paint()..color = const Color(0xFFCDE8F5),
    );

    final blockPaint = Paint()..color = const Color(0xFFE8E2D6);
    for (final r in [
      Rect.fromLTWH(s.width * 0.38, s.height * 0.10, s.width * 0.28, s.height * 0.22),
      Rect.fromLTWH(s.width * 0.10, s.height * 0.22, s.width * 0.20, s.height * 0.18),
      Rect.fromLTWH(s.width * 0.60, s.height * 0.40, s.width * 0.32, s.height * 0.20),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), blockPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.50, s.height * 0.14, s.width * 0.22, s.height * 0.18), const Radius.circular(3)),
      Paint()..color = const Color(0xFFD4EABC),
    );

    canvas.drawLine(Offset(0, s.height * 0.40), Offset(s.width, s.height * 0.46),
        Paint()..color = const Color(0xFFD8D0C0)..strokeWidth = 3.0..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(s.width * 0.45, 0), Offset(s.width * 0.52, s.height),
        Paint()..color = const Color(0xFFDDD8CE)..strokeWidth = 1.8..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(0, s.height * 0.62), Offset(s.width, s.height * 0.65),
        Paint()..color = const Color(0xFFDDD8CE)..strokeWidth = 1.2..strokeCap = StrokeCap.round);
  }

  void _paintStreets(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFFAFAF6));

    final blockPaint = Paint()..color = const Color(0xFFF0EAD8);
    for (final r in [
      Rect.fromLTWH(0, 0, s.width * 0.36, s.height * 0.38),
      Rect.fromLTWH(s.width * 0.42, 0, s.width, s.height * 0.38),
      Rect.fromLTWH(0, s.height * 0.44, s.width * 0.36, s.height),
      Rect.fromLTWH(s.width * 0.42, s.height * 0.44, s.width, s.height),
    ]) {
      canvas.drawRect(r, blockPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.08, s.height * 0.08, s.width * 0.22, s.height * 0.24), const Radius.circular(3)),
      Paint()..color = const Color(0xFFBCDFA4),
    );

    canvas.drawLine(Offset(0, s.height * 0.41), Offset(s.width, s.height * 0.41),
        Paint()..color = const Color(0xFF4A90D9)..strokeWidth = 4.5..strokeCap = StrokeCap.square);
    canvas.drawLine(Offset(s.width * 0.39, 0), Offset(s.width * 0.39, s.height),
        Paint()..color = const Color(0xFFD4CCB8)..strokeWidth = 1.8..strokeCap = StrokeCap.square);
    canvas.drawLine(Offset(0, s.height * 0.70), Offset(s.width, s.height * 0.70),
        Paint()..color = const Color(0xFFDDD6C4)..strokeWidth = 1.2..strokeCap = StrokeCap.square);
    canvas.drawLine(Offset(s.width * 0.68, 0), Offset(s.width * 0.68, s.height),
        Paint()..color = const Color(0xFFDDD6C4)..strokeWidth = 1.2..strokeCap = StrokeCap.square);

    canvas.drawCircle(Offset(s.width * 0.39, s.height * 0.41), 3.5,
        Paint()..color = const Color(0xFF4A90D9));
  }

  // 자동 테마 미리보기: 상단 절반 밝음(낮), 하단 절반 어두움(밤)
  void _paintNavDay(Canvas canvas, Size s) {
    // 밝은 네비게이션 배경
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE8F4FD));
    // 굵은 도로 (파란 고속도로 느낌)
    final roadPaint = Paint()..color = const Color(0xFF1E6FF0)..strokeWidth = s.width * 0.12..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.5), Offset(s.width, s.height * 0.5), roadPaint);
    final road2 = Paint()..color = const Color(0xFF60A5FA)..strokeWidth = s.width * 0.07..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.3, 0), Offset(s.width * 0.6, s.height), road2);
    // 방향 화살표
    final arrowPaint = Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round;
    final cx = s.width * 0.65; final cy = s.height * 0.5;
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), arrowPaint);
    canvas.drawLine(Offset(cx + 2, cy - 4), Offset(cx + 6, cy), arrowPaint);
    canvas.drawLine(Offset(cx + 2, cy + 4), Offset(cx + 6, cy), arrowPaint);
  }

  void _paintNavNight(Canvas canvas, Size s) {
    // 야간 네비게이션
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1A2533));
    final roadPaint = Paint()..color = const Color(0xFF2D4A6B)..strokeWidth = s.width * 0.14..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.5), Offset(s.width, s.height * 0.5), roadPaint);
    final road2 = Paint()..color = const Color(0xFF1E3A52)..strokeWidth = s.width * 0.08..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s.width * 0.25, 0), Offset(s.width * 0.55, s.height), road2);
    // 네온 강조 라인
    final glowPaint = Paint()..color = const Color(0xFF6BBBFF)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.5), Offset(s.width, s.height * 0.5), glowPaint);
    // 화살표
    final arrowPaint = Paint()..color = const Color(0xFF6BBBFF)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final cx = s.width * 0.65; final cy = s.height * 0.5;
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), arrowPaint);
    canvas.drawLine(Offset(cx + 2, cy - 4), Offset(cx + 6, cy), arrowPaint);
    canvas.drawLine(Offset(cx + 2, cy + 4), Offset(cx + 6, cy), arrowPaint);
  }

  void _paintSatellitePure(Canvas canvas, Size s) {
    // 순수 위성 — 레이블 없는 초록+갈색 지형
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1C3A1C));
    // 초록 식생
    canvas.drawOval(Rect.fromLTWH(s.width * 0.1, s.height * 0.15, s.width * 0.4, s.height * 0.35),
        Paint()..color = const Color(0xFF2D5A2D));
    canvas.drawOval(Rect.fromLTWH(s.width * 0.45, s.height * 0.4, s.width * 0.45, s.height * 0.45),
        Paint()..color = const Color(0xFF3A6B2A));
    // 갈색 도시 블록
    canvas.drawRect(Rect.fromLTWH(s.width * 0.55, s.height * 0.1, s.width * 0.35, s.height * 0.3),
        Paint()..color = const Color(0xFF5A4A2A));
    // 강 (파란 선)
    final riverPaint = Paint()..color = const Color(0xFF1A3A5C)..strokeWidth = s.width * 0.06..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.7), Offset(s.width * 0.6, s.height * 0.55), riverPaint);
    canvas.drawLine(Offset(s.width * 0.6, s.height * 0.55), Offset(s.width, s.height * 0.65), riverPaint);
  }

  void _paintStandardSatellite(Canvas canvas, Size s) {
    // 위성 배경
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1C3A1C));
    canvas.drawOval(Rect.fromLTWH(0, s.height * 0.3, s.width * 0.55, s.height * 0.5),
        Paint()..color = const Color(0xFF2D5A2D));
    canvas.drawRect(Rect.fromLTWH(s.width * 0.5, 0, s.width * 0.5, s.height * 0.55),
        Paint()..color = const Color(0xFF4A3A20));
    // 위에 3D 건물 오버레이
    final buildPaint = Paint()..color = const Color(0xCC8B9EB5);
    final sidePaint2 = Paint()..color = const Color(0xCC5A6F85);
    final roofP = Paint()..color = const Color(0xCCAFC2D4);
    void b(double x, double y, double w, double h, double d) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), buildPaint);
      canvas.drawPath(Path()
        ..moveTo(x+w,y)..lineTo(x+w+d,y-d*0.5)
        ..lineTo(x+w+d,y+h-d*0.5)..lineTo(x+w,y+h)..close(), sidePaint2);
      canvas.drawPath(Path()
        ..moveTo(x,y)..lineTo(x+d,y-d*0.5)
        ..lineTo(x+w+d,y-d*0.5)..lineTo(x+w,y)..close(), roofP);
    }
    b(s.width*0.1, s.height*0.35, s.width*0.22, s.height*0.38, 7);
    b(s.width*0.55, s.height*0.18, s.width*0.18, s.height*0.5, 7);
  }

  void _paintAuto(Canvas canvas, Size s) {
    // 낮 (상단)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height / 2),
      Paint()..color = const Color(0xFFEDE3CF),
    );
    // 밤 (하단)
    canvas.drawRect(
      Rect.fromLTWH(0, s.height / 2, s.width, s.height / 2),
      Paint()..color = const Color(0xFF0D1220),
    );
    // 구분선
    canvas.drawLine(
      Offset(0, s.height / 2),
      Offset(s.width, s.height / 2),
      Paint()..color = const Color(0xFF8B6CF6)..strokeWidth = 1.5,
    );
    // 태양 아이콘 (낮)
    canvas.drawCircle(
      Offset(s.width / 2, s.height * 0.28),
      s.width * 0.14,
      Paint()..color = const Color(0xFFFAB04A),
    );
    // 달 아이콘 (밤)
    canvas.drawCircle(
      Offset(s.width / 2, s.height * 0.72),
      s.width * 0.11,
      Paint()..color = const Color(0xFFCBBFFF),
    );
  }

  void _paintBuildings3d(Canvas canvas, Size s) {
    // 도로 배경
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF0F4F8));
    // 건물 블록 3개 — 원근감 있는 입체 직사각형
    final buildingPaint = Paint()..color = const Color(0xFFBEC8D8);
    final sidePaint = Paint()..color = const Color(0xFF94A3B8);
    final roofPaint = Paint()..color = const Color(0xFFE2E8F0);

    void drawBuilding(double x, double y, double w, double h, double depth) {
      // 정면
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), buildingPaint);
      // 오른쪽 면
      final sidePath = Path()
        ..moveTo(x + w, y)
        ..lineTo(x + w + depth, y - depth * 0.5)
        ..lineTo(x + w + depth, y + h - depth * 0.5)
        ..lineTo(x + w, y + h)
        ..close();
      canvas.drawPath(sidePath, sidePaint);
      // 지붕
      final roofPath = Path()
        ..moveTo(x, y)
        ..lineTo(x + depth, y - depth * 0.5)
        ..lineTo(x + w + depth, y - depth * 0.5)
        ..lineTo(x + w, y)
        ..close();
      canvas.drawPath(roofPath, roofPaint);
    }

    drawBuilding(s.width * 0.08, s.height * 0.38, s.width * 0.26, s.height * 0.42, 8);
    drawBuilding(s.width * 0.42, s.height * 0.22, s.width * 0.22, s.height * 0.58, 8);
    drawBuilding(s.width * 0.70, s.height * 0.34, s.width * 0.20, s.height * 0.48, 8);
  }

  @override
  bool shouldRepaint(_MapStylePainter old) => old.style != style;
}

// ─── 롱프레스 리플 페인터 ────────────────────────────────────────────────────

class _LongPressRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _LongPressRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Expanding translucent fill
    canvas.drawCircle(
      center,
      maxR * progress,
      Paint()
        ..color = color.withValues(alpha: 0.18 * (1.0 - progress * 0.4))
        ..style = PaintingStyle.fill,
    );

    // Expanding ring
    canvas.drawCircle(
      center,
      maxR * progress,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Progress arc (outer, fixed radius)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxR - 3),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Center dot
    canvas.drawCircle(
      center,
      3.5 + 2.0 * progress,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LongPressRipplePainter old) => old.progress != progress;
}

// ─── 알림 센터 시트 ───────────────────────────────────────────────────────────

class _NotificationCenterSheet extends ConsumerWidget {
  const _NotificationCenterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final primary = context.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom.clamp(0.0, 60.0);

    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '알림',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.labelColor,
              letterSpacing: -0.3,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '받은 친구 요청을 확인하세요',
            style: TextStyle(
              fontSize: 13,
              color: context.subLabelColor,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 20),
          requestsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (requests) {
              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'lib/img/notification-bell-svgrepo-com.svg',
                          width: 36,
                          height: 36,
                          colorFilter: ColorFilter.mode(
                            context.subLabelColor.withValues(alpha: 0.35),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '새 알림이 없어요',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.subLabelColor,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final req = requests[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_add_outlined, size: 20, color: primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${req.fromNickname} 님이 친구 요청을 보냈어요',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.labelColor,
                                  letterSpacing: -0.2,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                req.fromFriendCode,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.subLabelColor,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                await ref
                                    .read(socialServiceProvider)
                                    .rejectFriendRequest(req.id);
                                ref.invalidate(pendingRequestsProvider);
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: context.fieldBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.glassBorder),
                                ),
                                child: Icon(Icons.close_rounded, size: 17, color: context.subLabelColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final err = await ref
                                    .read(socialServiceProvider)
                                    .acceptFriendRequest(req.id, req.fromUid, req.fromNickname, req.fromFriendCode);
                                if (err == null) {
                                  await ref.read(friendsProvider.notifier).addFriend(
                                    req.fromFriendCode, req.fromNickname,
                                    uid: req.fromUid, notify: false,
                                  );
                                  ref.invalidate(friendsStreamProvider);
                                }
                                ref.invalidate(pendingRequestsProvider);
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: primary.withValues(alpha: 0.35)),
                                ),
                                child: Icon(Icons.check_rounded, size: 17, color: primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 새싹 애니메이션 오버레이 ──────────────────────────────────────────────────

class _PinSproutOverlay extends StatefulWidget {
  final PinModel pin;
  final Offset screenPos;
  final Color themeColor;

  const _PinSproutOverlay({
    super.key,
    required this.pin,
    required this.screenPos,
    required this.themeColor,
  });

  @override
  State<_PinSproutOverlay> createState() => _PinSproutOverlayState();
}

class _PinSproutOverlayState extends State<_PinSproutOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rings;
  late final Animation<double> _sparks;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    // 총 2100ms: 이펙트 피크(1100ms) + 줌아웃(950ms)
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..forward();

    // 링/파티클 이펙트
    _rings = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
    );
    _sparks = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.04, 0.52, curve: Curves.easeOut),
    );
    // 줌아웃 시작(52%)과 동기화해 페이드 아웃
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.52, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.addListener(() {
      if (_ctrl.value >= 0.04 && _ctrl.value < 0.06) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const w = 220.0;
    const center = Offset(w / 2, w / 2);
    final cx = widget.screenPos.dx;
    final cy = widget.screenPos.dy;

    final outerColor = widget.pin.pinOuterColor != null
        ? Color(widget.pin.pinOuterColor!)
        : widget.themeColor;

    return Positioned(
      left: cx - w / 2,
      top: cy - w / 2,
      width: w,
      height: w,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => Opacity(
            opacity: _exitFade.value.clamp(0.0, 1.0),
            child: CustomPaint(
              size: const Size(w, w),
              painter: _SproutEffectPainter(
                rings: _rings.value,
                sparks: _sparks.value,
                color: outerColor,
                center: center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SproutEffectPainter extends CustomPainter {
  final double rings;
  final double sparks;
  final Color color;
  final Offset center;

  static const _sparkAngles = <double>[
    -90, -60, -30, 0, 30, 60, -120, -150,
  ];

  const _SproutEffectPainter({
    required this.rings,
    required this.sparks,
    required this.color,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 링 (3개, stagger) ──
    const maxR = 76.0;
    const stagger = 0.22;
    for (var i = 0; i < 3; i++) {
      final t = ((rings - i * stagger) / (1 - i * stagger)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      canvas.drawCircle(
        center,
        t * maxR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = color.withValues(alpha: (1 - t) * 0.6),
      );
    }

    // ── 파티클 (8개) ──
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _sparkAngles.length; i++) {
      final delay = i * 0.06;
      final t = ((sparks - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final rad = _sparkAngles[i] * math.pi / 180;
      final dist = t * 56;
      paint.color = color.withValues(alpha: (1 - t) * 0.9);
      canvas.drawCircle(
        Offset(center.dx + math.cos(rad) * dist, center.dy + math.sin(rad) * dist),
        (1 - t) * 3.5 + 0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SproutEffectPainter old) =>
      old.rings != rings || old.sparks != sparks || old.color != color;
}



