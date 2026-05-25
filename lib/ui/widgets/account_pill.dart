import 'package:flutter/material.dart';

import '../../ui/theme/app_theme.dart';

/// A single pill in the account switcher rail.
///
/// States:
///  - normal:   grey bg, dim text, coloured status dot
///  - selected: blue bg, light text, lighter dot
///  - batch:    blue outline + checkmark, no dot
///  - expired:  red dot (session gone)
class AccountPill extends StatelessWidget {
  final String  label;
  final bool    isSelected;
  final bool    isBatchSelected;
  final bool    isSessionActive;
  final bool    isBatchMode;
  final VoidCallback  onTap;
  final VoidCallback? onLongPress;

  const AccountPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isBatchSelected,
    required this.isSessionActive,
    required this.isBatchMode,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final Border? border;

    if (isBatchMode) {
      bg        = isBatchSelected
          ? AppTheme.primary.withOpacity(0.18)
          : AppTheme.pillBg;
      textColor = isBatchSelected ? AppTheme.pillTextSel : AppTheme.pillText;
      border    = Border.all(
        color: isBatchSelected ? AppTheme.primary : AppTheme.border,
        width: isBatchSelected ? 1.5 : 0.5,
      );
    } else if (isSelected) {
      bg        = AppTheme.pillSelected;
      textColor = AppTheme.pillTextSel;
      border    = null;
    } else {
      bg        = AppTheme.pillBg;
      textColor = AppTheme.pillText;
      border    = Border.all(color: AppTheme.border, width: 0.5);
    }

    final dotColor = isSelected
        ? (isSessionActive ? const Color(0xFF9FE1CB) : const Color(0xFFFF9898))
        : (isSessionActive ? AppTheme.sessionActive : AppTheme.sessionExpired);

    return GestureDetector(
      onTap:      onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(20),
          border:       border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBatchMode && isBatchSelected) ...[
              Icon(Icons.check, size: 13, color: AppTheme.primary),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width:       7,
                height:      7,
                margin:      const EdgeInsets.only(right: 5),
                decoration:  BoxDecoration(
                  color:  dotColor,
                  shape:  BoxShape.circle,
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w500,
                color:      textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The + button at the end of the pill rail.
class AddAccountPill extends StatelessWidget {
  final VoidCallback onTap;

  const AddAccountPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  32,
        height: 32,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: const Icon(
          Icons.add,
          size:  16,
          color: AppTheme.onSurfaceDim,
        ),
      ),
    );
  }
}
