import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class GlassSheet extends StatelessWidget {
  final Widget child;
  final double? height;
  final VoidCallback? onClose;
  final bool centered;
  final Alignment alignment;

  const GlassSheet({
    super.key,
    required this.child,
    this.height,
    this.onClose,
    this.centered = false,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final card = Container(
      constraints: BoxConstraints(
        maxHeight: centered
            ? size.height * 0.65
            : (height ?? size.height * 0.72),
      ),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!centered)
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
              if (onClose != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: centered ? 14 : 0,
                    right: 15,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (centered) {
      return Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: alignment.y > 0 ? bottomInset + 16 : 0,
          ),
          child: card,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: card,
    );
  }
}
