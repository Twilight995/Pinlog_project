import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../application/providers/pin_provider.dart';
import '../../../data/models/pin_model.dart';

class PinCreateSheet extends ConsumerStatefulWidget {
  final LatLng location;
  final VoidCallback onClose;
  final VoidCallback onSaved;
  final PinModel? editPin;

  const PinCreateSheet({
    super.key,
    required this.location,
    required this.onClose,
    required this.onSaved,
    this.editPin,
  });

  @override
  ConsumerState<PinCreateSheet> createState() => _PinCreateSheetState();
}

class _PinCreateSheetState extends ConsumerState<PinCreateSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _companionCtrl;
  late String _selectedVisibility;
  late List<String> _companions;
  late List<String> _photoPaths;
  late DateTime _selectedDate;
  late LatLng _location;

  String? _locationName; // null = 로딩 중
  bool _showLocationSearch = false;
  bool _searchingLocation = false;
  final _locationSearchCtrl = TextEditingController();

  bool get _isEditing => widget.editPin != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editPin;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _companionCtrl = TextEditingController();
    _selectedVisibility = p?.visibility ?? AppConstants.visibilities.first;
    _companions = List.from(p?.companions ?? []);
    _photoPaths = List.from(p?.photoPaths ?? []);
    _selectedDate = p?.createdAt ?? DateTime.now();
    _location = widget.location;
    _resolveLocationName();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _companionCtrl.dispose();
    _locationSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveLocationName() async {
    if (!mounted) return;
    setState(() => _locationName = null);
    try {
      final marks = await placemarkFromCoordinates(
        _location.latitude,
        _location.longitude,
      );
      final m = marks.firstOrNull;
      if (mounted) {
        setState(() {
          _locationName = m != null
              ? [m.subLocality, m.locality]
                    .where((s) => s != null && s.isNotEmpty)
                    .map((s) => s!)
                    .join(' ')
                    .trim()
              : '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationName = '');
    }
  }

  Future<void> _searchLocation() async {
    final query = _locationSearchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searchingLocation = true);
    try {
      final results = await locationFromAddress(query);
      if (results.isNotEmpty && mounted) {
        final r = results.first;
        setState(() {
          _location = LatLng(r.latitude, r.longitude);
          _showLocationSearch = false;
          _locationSearchCtrl.clear();
          _searchingLocation = false;
        });
        _resolveLocationName();
      } else if (mounted) {
        setState(() => _searchingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty && mounted) {
      setState(() {
        for (final img in images) {
          if (_photoPaths.length < 5) _photoPaths.add(img.path);
        }
      });
    }
  }

  void _addCompanion() {
    final text = _companionCtrl.text.trim();
    if (text.isEmpty || _companions.contains(text)) return;
    setState(() {
      _companions.add(text);
      _companionCtrl.clear();
    });
  }

  String _isoToFlag(String code) {
    if (code.length != 2) return '';
    final a = String.fromCharCode(code.codeUnitAt(0) - 0x41 + 0x1F1E6);
    final b = String.fromCharCode(code.codeUnitAt(1) - 0x41 + 0x1F1E6);
    return a + b;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);

    // 새 핀이면 역지오코딩으로 국가 코드 취득 (편집 시엔 기존 값 유지)
    String countryCode = widget.editPin?.countryCode ?? '';
    if (!_isEditing) {
      try {
        final marks = await placemarkFromCoordinates(
          _location.latitude,
          _location.longitude,
        );
        countryCode = marks.firstOrNull?.isoCountryCode?.toUpperCase() ?? '';
      } catch (_) {}
    }

    final pin = PinModel(
      id: _isEditing ? widget.editPin!.id : const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: '',
      latitude: _location.latitude,
      longitude: _location.longitude,
      emotion: widget.editPin?.emotion ?? AppConstants.emotions.first,
      weather: widget.editPin?.weather ?? AppConstants.weathers.first,
      companions: List.from(_companions),
      intensityLevel: widget.editPin?.intensityLevel ?? 3,
      pinShape: widget.editPin?.pinShape ?? AppConstants.pinShapes.first,
      visibility: _selectedVisibility,
      photoPaths: List.from(_photoPaths),
      createdAt: _selectedDate,
      sharedMapId: widget.editPin?.sharedMapId,
      countryCode: countryCode,
      pinOuterColor: widget.editPin?.pinOuterColor,
      pinInnerColor: widget.editPin?.pinInnerColor,
    );

    if (_isEditing) {
      ref.read(pinsProvider.notifier).update(pin);
    } else {
      ref.read(pinsProvider.notifier).add(pin);
    }

    if (context.mounted) {
      final flagEmoji = _isoToFlag(countryCode);
      final label = _isEditing
          ? '핀이 수정됐어요'
          : flagEmoji.isNotEmpty
          ? '핀이 심어졌어요  $flagEmoji'
          : '핀이 지도에 심어졌어요';
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppColors.dark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        ),
      );
    }

    widget.onSaved();
  }

  InputDecoration _inputDeco(
    String hint, {
    EdgeInsets? contentPadding,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.hintColor, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: context.fieldBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    suffixIcon: suffix,
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: context.sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: context.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 드래그 핸들
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.handleColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        _isEditing ? '기억 수정하기' : '새 핀 기록',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.labelColor,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: context.emptyStateBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.greyLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 스크롤 영역
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목
                        TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _inputDeco('이곳의 기억을 한 줄로 요약한다면?'),
                        ),
                        const SizedBox(height: 16),

                        // 동행자
                        const _SectionLabel('동행자'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _companionCtrl,
                                style: const TextStyle(fontSize: 14),
                                onSubmitted: (_) => _addCompanion(),
                                decoration: _inputDeco(
                                  '이름 입력 후 추가',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _addCompanion,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: context.primaryColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: _companions.isNotEmpty
                              ? Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _companions
                                      .map(
                                        (c) => Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            10,
                                            5,
                                            6,
                                            5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.dark,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.person_rounded,
                                                size: 11,
                                                color: Colors.white70,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () => setState(
                                                  () => _companions.remove(c),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 12,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                )
                              : Text(
                                  '함께한 사람을 추가해보세요',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.hintColor,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // 사진 (최대 5장)
                        const _SectionLabel('사진 (최대 5장)'),
                        SizedBox(
                          height: 84,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              if (_photoPaths.length < 5)
                                GestureDetector(
                                  onTap: _pickPhotos,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: context.chipBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: context.chipBorder,
                                      ),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 24,
                                          color: AppColors.greyLight,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '추가',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.greyLight,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ..._photoPaths.map(
                                (path) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.file(
                                          File(path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stack,
                                              ) => Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.grey.withValues(
                                                  alpha: 0.2,
                                                ),
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: AppColors.greyLight,
                                                ),
                                              ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _photoPaths.remove(path),
                                          ),
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 12,
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
                        ),
                        const SizedBox(height: 16),

                        // 공개 범위
                        const _SectionLabel('공개 범위'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: AppConstants.visibilities
                              .map(
                                (v) => _Chip(
                                  label: _visibilityLabel(v),
                                  isActive: _selectedVisibility == v,
                                  activeColor: AppColors.dark,
                                  textColor: Colors.white,
                                  onTap: () =>
                                      setState(() => _selectedVisibility = v),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),

                        // 위치
                        const _SectionLabel('위치'),
                        GestureDetector(
                          onTap: () => setState(
                            () => _showLocationSearch = !_showLocationSearch,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: context.fieldBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _showLocationSearch
                                    ? context.primaryColor
                                    : context.chipBorder,
                                width: _showLocationSearch ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 16,
                                  color: context.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _locationName == null
                                      ? Text(
                                          '위치 확인 중...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.hintColor,
                                          ),
                                        )
                                      : Text(
                                          _locationName!.isEmpty
                                              ? '${_location.latitude.toStringAsFixed(5)}, ${_location.longitude.toStringAsFixed(5)}'
                                              : _locationName!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.labelColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                                AnimatedRotation(
                                  turns: _showLocationSearch ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: context.subLabelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: _showLocationSearch
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _locationSearchCtrl,
                                          style: const TextStyle(fontSize: 14),
                                          onSubmitted: (_) => _searchLocation(),
                                          decoration: _inputDeco(
                                            '동네, 도시, 주소 검색',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 13,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _searchLocation,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: context.primaryColor,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: _searchingLocation
                                              ? const Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.search_rounded,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),

                        // 날짜 & 시간
                        const _SectionLabel('날짜 & 시간'),
                        Row(
                          children: [
                            // 날짜 선택
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: Theme.of(ctx).colorScheme
                                            .copyWith(
                                              primary: context.primaryColor,
                                              onPrimary: Colors.white,
                                            ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null && mounted) {
                                    setState(
                                      () => _selectedDate = DateTime(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                        _selectedDate.hour,
                                        _selectedDate.minute,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.fieldBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.chipBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 15,
                                        color: context.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.labelColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 시간 선택
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      _selectedDate,
                                    ),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: Theme.of(ctx).colorScheme
                                            .copyWith(
                                              primary: context.primaryColor,
                                              onPrimary: Colors.white,
                                            ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null && mounted) {
                                    setState(
                                      () => _selectedDate = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        picked.hour,
                                        picked.minute,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.fieldBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.chipBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 15,
                                        color: context.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.labelColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 저장 버튼
                        GestureDetector(
                          onTap: _save,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [context.primaryLightColor, context.primaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: context.primaryColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _isEditing ? '수정 완료' : '기록 심기',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

String _visibilityLabel(String v) {
  if (v.contains('전체')) return '전체 공개';
  if (v.contains('친구')) return '친구 공개';
  if (v.contains('나만')) return '나만 보기';
  return v;
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color? textColor;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : context.chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : context.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive
                ? (textColor ?? AppColors.dark)
                : AppColors.greyLight,
          ),
        ),
      ),
    );
  }
}
