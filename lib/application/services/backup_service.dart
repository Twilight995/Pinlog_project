import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/pin_model.dart';

class BackupService {
  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> exportPins(List<PinModel> pins, {Rect? sharePositionOrigin}) async {
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'pins': pins.map(_pinToMap).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/pinlog_backup_$stamp.json');
    await file.writeAsString(json, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Pinlog 백업 파일',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<List<PinModel>> importFromJson(String jsonStr) async {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = map['pins'] as List<dynamic>;
    return list
        .map((e) => _pinFromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> _pinToMap(PinModel p) => {
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'emotion': p.emotion,
        'weather': p.weather,
        'companions': p.companions,
        'intensityLevel': p.intensityLevel,
        'pinShape': p.pinShape,
        'visibility': p.visibility,
        'photoPaths': p.photoPaths,
        'countryCode': p.countryCode,
        'taggedFriendCodes': p.taggedFriendCodes,
        'createdAt': p.createdAt.toIso8601String(),
      };

  PinModel _pinFromMap(Map<String, dynamic> m) => PinModel(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        emotion: m['emotion'] as String? ?? '좋아요',
        weather: m['weather'] as String? ?? '맑음',
        companions: (m['companions'] as List?)?.cast<String>() ?? [],
        intensityLevel: m['intensityLevel'] as int? ?? 3,
        pinShape: m['pinShape'] as String? ?? 'star',
        visibility: m['visibility'] as String? ?? '🔒 나만 보기',
        photoPaths: (m['photoPaths'] as List?)?.cast<String>() ?? [],
        countryCode: m['countryCode'] as String? ?? '',
        taggedFriendCodes: (m['taggedFriendCodes'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

final backupService = BackupService();
