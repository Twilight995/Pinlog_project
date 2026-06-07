import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/providers/meeting_provider.dart';
import '../../../application/services/social_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/meeting.dart';
import '../../screens/meeting/location_picker_screen.dart';

class MeetingCreateSheet extends ConsumerStatefulWidget {
  const MeetingCreateSheet({super.key});

  @override
  ConsumerState<MeetingCreateSheet> createState() => _MeetingCreateSheetState();
}

class _MeetingCreateSheetState extends ConsumerState<MeetingCreateSheet> {
  LocationPickResult? _pickedLocation;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  TransitMode _transitMode = TransitMode.transit;
  String? _selectedFriendUid;
  bool _isLoading = false;

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

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _pickedLocation),
        fullscreenDialog: true,
      ),
    );
    if (result != null) setState(() => _pickedLocation = result);
  }

  Future<void> _submit() async {
    // ── 1. 기본 필드 검증 ─────────────────────────────────────────────
    if (_selectedFriendUid == null) {
      _showDialog('친구를 선택해주세요', '약속을 잡을 친구를 먼저 선택해주세요.');
      return;
    }
    if (_pickedLocation == null) {
      _showDialog('장소를 선택해주세요', '지도에서 만날 장소를 먼저 선택해주세요.');
      return;
    }

    HapticFeedback.mediumImpact();

    // ── 2. 데모 친구 → Supabase 건너뛰고 즉시 주입 ───────────────────
    if (_selectedFriendUid!.startsWith('demo_')) {
      ref.read(meetingProvider.notifier).injectDemoMeeting();
      if (mounted) Navigator.pop(context, true);
      return;
    }

    setState(() => _isLoading = true);

    // ── 3. 약속 생성 ──────────────────────────────────────────────────
    final loc = _pickedLocation!;
    final success = await ref.read(meetingProvider.notifier).createMeeting(
          inviteeUid: _selectedFriendUid!,
          targetLat: loc.lat,
          targetLng: loc.lng,
          targetName: loc.name,
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
    // Supabase stream friends (다른 폰에서 추가된 친구 포함) 우선, 없으면 로컬
    final supaFriends = ref.watch(friendsStreamProvider).valueOrNull;
    final localFriends = ref.watch(friendsProvider);
    final friends = (supaFriends != null && supaFriends.isNotEmpty)
        ? supaFriends
        : localFriends;
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

          // 장소 선택 (지도 피커)
          _SectionLabel(label: '만날 장소'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openLocationPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pickedLocation != null
                      ? primary.withValues(alpha: 0.55)
                      : context.glassBorder,
                  width: _pickedLocation != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: _pickedLocation != null ? primary : context.subLabelColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pickedLocation?.name ?? '지도에서 장소 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                        color: _pickedLocation != null
                            ? context.labelColor
                            : context.subLabelColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: context.subLabelColor),
                ],
              ),
            ),
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

