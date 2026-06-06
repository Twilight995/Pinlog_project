import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/providers/meeting_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/meeting.dart';

class MeetingCreateSheet extends ConsumerStatefulWidget {
  const MeetingCreateSheet({super.key});

  @override
  ConsumerState<MeetingCreateSheet> createState() => _MeetingCreateSheetState();
}

class _MeetingCreateSheetState extends ConsumerState<MeetingCreateSheet> {
  final _locationCtrl = TextEditingController();
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  TransitMode _transitMode = TransitMode.transit;
  String? _selectedFriendUid;
  bool _isLoading = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    DateTime picked = _scheduledAt;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 260,
        color: context.cardBg,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text('완료', style: TextStyle(color: context.primaryColor)),
                  onPressed: () {
                    setState(() => _scheduledAt = picked);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: _scheduledAt,
                minimumDate: DateTime.now(),
                use24hFormat: true,
                onDateTimeChanged: (dt) => picked = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final input = _locationCtrl.text.trim();

    // ── 1. 기본 필드 검증 ─────────────────────────────────────────────
    if (_selectedFriendUid == null) {
      _showDialog('친구를 선택해주세요', '약속을 잡을 친구를 먼저 선택해주세요.');
      return;
    }
    if (input.isEmpty) {
      _showDialog('장소를 입력해주세요', '만날 장소를 입력해주세요.');
      return;
    }

    // ── 2. 장소명 형식 검증 (숫자만 / 의미없는 입력 차단) ─────────────
    final hasLetter = input.contains(RegExp(r'[가-힣a-zA-Z]'));
    if (!hasLetter) {
      _showDialog(
        '올바른 장소명을 입력해주세요',
        '숫자만 입력하거나 의미없는 문자는 사용할 수 없어요.\n예) 강남역 2번 출구, 홍대입구역',
      );
      return;
    }
    if (input.length < 2) {
      _showDialog('장소명이 너무 짧아요', '정확한 장소명을 2글자 이상 입력해주세요.');
      return;
    }

    HapticFeedback.mediumImpact();

    // ── 3. 데모 친구 → Supabase 건너뛰고 즉시 주입 ───────────────────
    if (_selectedFriendUid!.startsWith('demo_')) {
      ref.read(meetingProvider.notifier).injectDemoMeeting();
      if (mounted) Navigator.pop(context, true);
      return;
    }

    setState(() => _isLoading = true);

    // ── 4. 지오코딩 (8초 타임아웃) ────────────────────────────────────
    double? targetLat;
    double? targetLng;
    try {
      final locations = await locationFromAddress(input)
          .timeout(const Duration(seconds: 8));
      if (locations.isNotEmpty) {
        targetLat = locations.first.latitude;
        targetLng = locations.first.longitude;
      }
    } catch (_) {}

    if (!mounted) return;

    if (targetLat == null || targetLng == null) {
      setState(() => _isLoading = false);
      _showDialog(
        '장소를 찾을 수 없어요',
        '"$input"에 해당하는 위치를 찾지 못했어요.\n더 정확한 주소나 장소명으로 다시 시도해주세요.',
      );
      return;
    }

    // ── 5. 한국 좌표 범위 검증 ─────────────────────────────────────────
    const minLat = 33.0; const maxLat = 39.0;
    const minLng = 124.0; const maxLng = 132.0;
    if (targetLat < minLat || targetLat > maxLat ||
        targetLng < minLng || targetLng > maxLng) {
      setState(() => _isLoading = false);
      _showDialog(
        '국내 장소만 입력 가능해요',
        '현재 한국 내 장소만 지원합니다.\n국내 지명으로 다시 입력해주세요.',
      );
      return;
    }

    // ── 6. 약속 생성 ──────────────────────────────────────────────────
    final success = await ref.read(meetingProvider.notifier).createMeeting(
          inviteeUid: _selectedFriendUid!,
          targetLat: targetLat,
          targetLng: targetLng,
          targetName: input,
          scheduledAt: _scheduledAt,
          transitMode: _transitMode,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context, true);
    } else {
      _showDialog('약속 생성 실패', '서버 오류가 발생했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  void _showDialog(String title, String message) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.labelColor,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: context.subLabelColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '확인',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final primary = context.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('약속 잡기',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: context.labelColor, fontFamily: 'Pretendard',
              )),
          const SizedBox(height: 20),

          // 친구 선택
          _SectionLabel(label: '친구 선택'),
          const SizedBox(height: 8),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('등록된 친구가 없습니다. 프로필에서 친구를 추가하세요.',
                  style: TextStyle(fontSize: 13, color: context.subLabelColor)),
            )
          else
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: friends.length,
                separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = friends[i];
                  final selected = _selectedFriendUid == f.supabaseUid;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFriendUid = f.supabaseUid);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? primary.withValues(alpha: 0.15) : context.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected ? primary : context.glassBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(f.name,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: selected ? primary : context.labelColor,
                          )),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // 장소 입력
          _SectionLabel(label: '만날 장소'),
          const SizedBox(height: 8),
          _GlassField(
            controller: _locationCtrl,
            hint: '예) 강남역 2번 출구',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 16),

          // 시간 선택
          _SectionLabel(label: '약속 시간'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 18, color: context.subLabelColor),
                  const SizedBox(width: 10),
                  Text(
                    _formatDateTime(_scheduledAt),
                    style: TextStyle(fontSize: 14, color: context.labelColor, fontFamily: 'Pretendard'),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18, color: context.subLabelColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 교통수단
          _SectionLabel(label: '이동 수단'),
          const SizedBox(height: 8),
          Row(
            children: TransitMode.values.map((mode) {
              final selected = _transitMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _transitMode = mode);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: mode == TransitMode.walking ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? primary.withValues(alpha: 0.12) : context.bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? primary : context.glassBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          _svgForMode(mode),
                          width: 20, height: 20,
                          colorFilter: ColorFilter.mode(
                            selected ? primary : context.subLabelColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_labelForMode(mode),
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: selected ? primary : context.subLabelColor,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 확인 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedOpacity(
              opacity: _isLoading ? 0.7 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('약속 만들기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = ['1월', '2월', '3월', '4월', '5월', '6월',
                    '7월', '8월', '9월', '10월', '11월', '12월'];
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month > 0 ? months[dt.month - 1] : ""} ${dt.day}일 (${weekdays[dt.weekday - 1]}) $h:$m';
  }

  String _svgForMode(TransitMode mode) => switch (mode) {
        TransitMode.driving => 'lib/img/car-svgrepo-com.svg',
        TransitMode.transit => 'lib/img/bus-svgrepo-com.svg',
        TransitMode.walking => 'lib/img/walk-svgrepo-com.svg',
      };

  String _labelForMode(TransitMode mode) => switch (mode) {
        TransitMode.driving => '자동차',
        TransitMode.transit => '대중교통',
        TransitMode.walking => '도보',
      };
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: context.subLabelColor, letterSpacing: 0.3,
        ));
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _GlassField({required this.controller, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 14, color: context.labelColor, fontFamily: 'Pretendard'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.subLabelColor, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: context.subLabelColor),
        filled: true,
        fillColor: context.bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
