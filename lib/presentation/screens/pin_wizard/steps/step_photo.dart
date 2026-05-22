import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../wizard_scaffold.dart';
import '../wizard_state.dart';

/// 위자드 Step 1 — 사진.
///
/// "이 순간을 사진으로 남길까요?" — 큰 사진 추가 영역 + 썸네일.
class StepPhoto extends StatelessWidget {
  final WizardData data;
  final int totalSteps;
  final int currentStep;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// 부모 setState 트리거 — 사진 추가/삭제 시 호출.
  final VoidCallback onChange;

  const StepPhoto({
    super.key,
    required this.data,
    required this.totalSteps,
    required this.currentStep,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onChange,
  });

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;
    final remaining = 5 - data.photoPaths.length;
    final newPaths = List<String>.from(data.photoPaths)
      ..addAll(images.take(remaining).map((x) => x.path));
    data.photoPaths = newPaths;
    onChange();
  }

  void _remove(String path) {
    data.photoPaths = data.photoPaths.where((p) => p != path).toList();
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = data.photoPaths.isNotEmpty;
    return WizardScaffold(
      totalSteps: totalSteps,
      currentStep: currentStep,
      stepLabel: 'STEP 1 OF 4',
      questionTop: '이 순간을',
      questionBottom: '사진으로 남길까요?',
      subtitle: '최대 5장까지 · 나중에 추가해도 좋아요',
      onClose: onClose,
      onBack: onBack,
      footer: WizardFooter(
        primaryLabel: '다음',
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: onNext,
        skipLabel: hasPhotos ? null : '건너뛰기',
        onSkip: hasPhotos ? null : onSkip,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 메인 사진 추가 영역 — 사진 없을 때만 큰 박스
          if (!hasPhotos)
            Expanded(
              child: GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppOverlays.w06,
                    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                    border: Border.all(
                      color: TabTheme.map.accent.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: TabTheme.map.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_a_photo_rounded,
                          size: 32,
                          color: TabTheme.map.accent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '사진 추가하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: AppTokens.fontDisplay,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '앨범에서 선택하거나 촬영',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          fontFamily: AppTokens.fontBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // 사진 있을 때 — 큰 그리드 (최대 5장)
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: data.photoPaths.length +
                    (data.photoPaths.length < 5 ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == data.photoPaths.length) {
                    return _AddTile(onTap: _pickPhotos);
                  }
                  final path = data.photoPaths[i];
                  return _PhotoTile(path: path, onRemove: () => _remove(path));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppOverlays.w06,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppOverlays.w15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              size: 26,
              color: AppOverlays.w50,
            ),
            const SizedBox(height: 4),
            Text(
              '추가',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppOverlays.w50,
                fontFamily: AppTokens.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _PhotoTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.bgLockedStart,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
