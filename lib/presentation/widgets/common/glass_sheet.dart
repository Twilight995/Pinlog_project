import 'package:flutter/material.dart';
import 'dart:ui';

import '../../../core/theme/app_theme.dart';

class GlassSheet extends StatelessWidget {
  final Widget child;
  final double? height;
  final VoidCallback? onClose;

  const GlassSheet({
    super.key,
    required this.child,
    this.height,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 100,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: height ?? 480,
            decoration: BoxDecoration(
              color: context.sheetBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
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
                // 닫기 버튼
                if (onClose != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 15, top: 0),
                      child: GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: context.emptyStateBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: AppColors.greyLight),
                        ),
                      ),
                    ),
                  ),
                // 내용
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: child,
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
