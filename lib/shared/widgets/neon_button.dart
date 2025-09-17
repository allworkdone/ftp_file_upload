import 'package:flutter/material.dart';
import 'package:file_upload/app/theme/app_colors.dart';

class NeonButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isRounded;
  final Color? backgroundColor;
  final Color? textColor;

  const NeonButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = true,
    this.isRounded = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? (isPrimary ? AppColors.primary : Colors.white);
    final fgColor = textColor ?? (isPrimary ? Colors.white : AppColors.primary);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isRounded ? 16 : 12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: isPrimary
                      ? AppColors.primaryLight.withOpacity(0.6)
                      : Colors.white.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: isPrimary
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.white.withOpacity(0.2),
                  blurRadius: 25,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: fgColor),
        label: Text(label, style: TextStyle(color: fgColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isRounded ? 16 : 12),
            side: BorderSide(
                color: isPrimary
                    ? AppColors.primaryLight.withOpacity(0.5)
                    : Colors.white.withOpacity(0.5),
                width: 1),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}