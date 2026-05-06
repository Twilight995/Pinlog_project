import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../application/providers/pin_provider.dart';
import '../../../data/models/pin_model.dart';
import '../common/glass_sheet.dart';
import 'pin_create_sheet.dart';

class PinDetailSheet extends ConsumerWidget {
  final String pinId;
  final VoidCallback onClose;

  const PinDetailSheet({super.key, required this.pinId, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(pinsProvider);
    final pin = pins.where((p) => p.id == pinId).firstOrNull;

    if (pin == null) return const SizedBox.shrink();

    return GlassSheet(
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            pin.title,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: context.labelColor, height: 1.3),
          ),
          const SizedBox(height: 10),

          // 뱃지 (감정 + 날씨 + 공개범위)
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _Badge(label: pin.emotion, color: AppColors.primary, textColor: AppColors.dark),
              _Badge(label: pin.weather),
              _Badge(label: pin.visibility),
            ],
          ),
          const SizedBox(height: 8),

          // 날짜
          Text(
            DateFormat('yyyy년 M월 d일').format(pin.createdAt),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey),
          ),
          const SizedBox(height: 4),

          // 주소 (역지오코딩)
          _AddressLine(lat: pin.latitude, lng: pin.longitude),
          const SizedBox(height: 10),

          // 감정 강도
          Row(
            children: [
              const Text('감정 강도 ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey)),
              ...List.generate(5, (i) => Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (i + 1) <= pin.intensityLevel
                      ? AppColors.primary
                      : context.emptyStateBg,
                ),
              )),
            ],
          ),
          const SizedBox(height: 10),

          // 동행자
          if (pin.companions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.people_outline, size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                const Text('함께 ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey)),
                Expanded(
                  child: Text(
                    pin.companions.join(', '),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 설명
          if (pin.description.isNotEmpty) ...[
            Text(
              pin.description,
              style: TextStyle(fontSize: 14, color: context.labelColor, height: 1.6, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
          ],

          // 사진 갤러리
          if (pin.photoPaths.isNotEmpty) ...[
            _PhotoGallery(paths: pin.photoPaths),
            const SizedBox(height: 12),
          ],

          // 편집 / 삭제
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openEditSheet(context, ref, pin),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('편집', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.greyLight),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(pinsProvider.notifier).remove(pin.id);
                    onClose();
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref, PinModel pin) {
    showAppSheet<void>(
      context,
      builder: (_) => PinCreateSheet(
        location: LatLng(pin.latitude, pin.longitude),
        editPin: pin,
        onClose: () => Navigator.of(context).pop(),
        onSaved: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// 역지오코딩 주소 표시
class _AddressLine extends StatefulWidget {
  final double lat;
  final double lng;
  const _AddressLine({required this.lat, required this.lng});

  @override
  State<_AddressLine> createState() => _AddressLineState();
}

class _AddressLineState extends State<_AddressLine> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final placemarks = await placemarkFromCoordinates(widget.lat, widget.lng);
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [p.administrativeArea, p.subLocality, p.locality]
          .where((s) => s != null && s.isNotEmpty)
          .toSet()
          .toList();
      if (mounted && parts.isNotEmpty) {
        setState(() => _address = parts.take(2).join(' '));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_address == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.grey),
        const SizedBox(width: 3),
        Text(_address!, style: const TextStyle(fontSize: 12, color: AppColors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// 사진 갤러리 (가로 스크롤)
class _PhotoGallery extends StatefulWidget {
  final List<String> paths;
  const _PhotoGallery({required this.paths});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.paths.length == 1) {
      return _buildPhoto(widget.paths.first, width: double.infinity, height: 180);
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildPhoto(widget.paths[i], width: double.infinity, height: 180),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.paths.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == _currentIndex ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i == _currentIndex ? context.labelColor : context.countBadgeBg,
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildPhoto(String path, {required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: width,
          height: height,
          color: Colors.grey.withValues(alpha: 0.15),
          child: const Icon(Icons.broken_image_outlined, color: AppColors.greyLight, size: 32),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const _Badge({required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? context.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? context.chipBorder),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor ?? AppColors.greyLight),
      ),
    );
  }
}
