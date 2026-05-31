import 'package:flutter/material.dart';
import 'dart:ui';

import '../../../core/theme/app_theme.dart';

class GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final double size;

  const GlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.dark
                  : context.glassBtnBg,
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: context.glassBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? context.primaryColor : context.labelColor,
            ),
          ),
        ),
      ),
    );
  }
}
