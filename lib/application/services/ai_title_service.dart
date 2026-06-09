import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/secrets.dart';

class AiTitleService {
  AiTitleService._();
  static final instance = AiTitleService._();

  GenerativeModel? _model;

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: Secrets.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 128,
      ),
    );
    return _model!;
  }

  /// 사진 경로(로컬)와 카테고리를 받아 한국어 제목 4개를 반환.
  /// 사진이 없으면 텍스트 전용으로 요청.
  /// 실패 시 빈 리스트 반환 (caller가 fallback 처리).
  Future<List<String>> suggestTitles({
    required String category,
    String? photoPath,
    String? emotion,
  }) async {
    try {
      final emotionHint = emotion != null && emotion.isNotEmpty
          ? '감정: $emotion\n'
          : '';

      final prompt = '''당신은 위치 기반 일기 앱 Pinlog의 제목 추천 AI입니다.
카테고리: $category
$emotionHint위 정보를 바탕으로 핀 제목을 4개 추천해주세요.
조건:
- 한국어
- 각 제목 15자 이내
- 감성적이고 기억에 남는 표현
- 제목만 출력 (번호, 설명, 기호 없이, 줄바꿈으로만 구분)''';

      List<Part> parts = [TextPart(prompt)];

      if (photoPath != null && photoPath.isNotEmpty) {
        final file = File(photoPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          parts = [
            TextPart(prompt),
            DataPart('image/jpeg', bytes),
          ];
        }
      }

      final response = await _gemini
          .generateContent([Content.multi(parts)])
          .timeout(const Duration(seconds: 10));

      final text = response.text ?? '';
      final titles = text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s.length <= 20)
          .take(4)
          .toList();

      return titles;
    } catch (e) {
      debugPrint('[AiTitleService] error: $e');
      return [];
    }
  }
}
