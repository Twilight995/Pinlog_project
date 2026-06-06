import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';
import '../wizard_style.dart';

// 카테고리별 AI 제목 제안
const _kCategorySuggestions = <String, List<String>>{
  'cafe':       ['첫 방문 카페', '혼자 마신 아메리카노', '오랜만에 마신 라떼', '창가 자리에서 보낸 오후'],
  'drinking':   ['퇴근 후 첫 한 잔', '오랜 친구와의 술자리', '분위기 좋은 이자카야', '이 맥주가 맞았다'],
  'shopping':   ['득템한 날', '윈도우 쇼핑만 했는데', '선물 고르러 온 날', '결국 샀다'],
  'drive':      ['한강 드라이브', '새벽 드라이브', '목적지 없는 드라이브', '가을 드라이브'],
  'running':    ['오늘도 달렸다', '첫 5km 완주', '새벽 러닝', '비 오는 날 달리기'],
  'gym':        ['오늘 운동 완료', 'PR 달성한 날', '꾸준히 3개월', '헬스장 첫 방문'],
  'soccer':     ['풋살 골 넣은 날', '팀 첫 승리', '주말 축구 모임', '드리블 성공'],
  'basketball': ['쓰리포인트 성공', '팀플레이가 맞은 날', '농구장 야경', '픽업 게임'],
  'baseball':   ['직관 다녀온 날', '홈런 보는 순간', '야구장 치킨', '응원단이 된 날'],
  'reading':    ['한 권 다 읽었다', '독서카페 오후', '이 문장이 좋았다', '밑줄 그은 페이지'],
  'selfdev':    ['배운 것을 적어두자', '강의 완강', '공부가 잘된 날', '새로운 걸 알게 된 날'],
  'game':       ['드디어 클리어', '같이 한 멀티', '오랜만에 게임', 'OP 조합 발견'],
  'tech':       ['새 기기 언박싱', '셋업 완성', '첫 인상 리뷰', '이 기능이 좋다'],
  'palace':     ['역사를 걷는 날', '고궁 산책', '한복 입고 나들이', '서울의 고즈넉함'],
};

List<String> _suggestionsFor(String pinShape) =>
    _kCategorySuggestions[pinShape] ?? ['오늘의 기억', '특별한 순간', '기록해두고 싶은 날'];

/// 위자드 Step 3 — 제목.
///
/// "이 순간을 / 한 줄로 적는다면?" — 큰 입력 카드 + 카테고리 기반 AI 제목 제안.
/// 제목은 필수이므로 건너뛰기 없음.
class StepTitle extends StatefulWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// 부모 setState 트리거.
  final VoidCallback onChange;

  const StepTitle({
    super.key,
    required this.data,
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onChange,
  });

  @override
  State<StepTitle> createState() => _StepTitleState();
}

class _StepTitleState extends State<StepTitle> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  static const _maxLength = 40;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.data.title);
    _focus = FocusNode();
    _ctrl.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChange() {
    widget.data.title = _ctrl.text;
    widget.onChange();
    setState(() {});
  }

  void _applyExample(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final length = _ctrl.text.length;
    final valid = _ctrl.text.trim().isNotEmpty;

    return WizardScaffold(
      totalSteps: widget.totalSteps,
      currentStep: widget.currentStep,
      stepLabel: 'STEP ${widget.currentStep + 1} OF ${widget.totalSteps}',
      questionTop: '이 순간을',
      questionBottom: '한 줄로 적는다면?',
      subtitle: '나중에 돌아봤을 때 떠오를 한 마디',
      onClose: widget.onClose,
      onBack: widget.onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: widget.onNext,
        primaryEnabled: valid,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Builder(
          builder: (ctx) {
            final ws = ctx.ws;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 큰 입력 카드
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ws.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                    border: Border.all(
                      color: TabTheme.map.accent.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        maxLines: 2,
                        minLines: 1,
                        maxLength: _maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ws.onSurface,
                          fontFamily: AppTokens.fontDisplay,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          counterText: '',
                          hintText: '예: 성수동에서 처음 마신 커피',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: ws.hint,
                            fontFamily: AppTokens.fontDisplay,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$length / $_maxLength',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ws.muted,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // AI 추천 제목 (선택한 카테고리 기반)
                Row(
                  children: [
                    Text(
                      '추천 제목',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ws.muted,
                        letterSpacing: 0.3,
                        fontFamily: AppTokens.fontBody,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: TabTheme.map.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppConstants.pinShapeNames[widget.data.pinShape] ?? widget.data.pinShape,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TabTheme.map.accent,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: _suggestionsFor(widget.data.pinShape).map((s) =>
                    GestureDetector(
                      onTap: () => _applyExample(s),
                      child: _ExampleChip(text: s, selected: s == _ctrl.text),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String text;
  final bool selected;
  const _ExampleChip({required this.text, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final ws = context.ws;
    final accent = context.primaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.12) : ws.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.65) : ws.surfaceBorder,
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? accent : ws.onSurface.withValues(alpha: 0.65),
          fontFamily: AppTokens.fontBody,
        ),
      ),
    );
  }
}

