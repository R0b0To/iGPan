import 'package:flutter/material.dart';

import '../../ui/theme/app_theme.dart';

/// The blue action bar that appears at the top of the action area
/// when one or more accounts are selected for batch operations.
class BatchBar extends StatelessWidget {
  final int          selectedCount;
  final bool         isRunning;
  final VoidCallback onClaimAll;
  final VoidCallback onRepairAll;
  final VoidCallback onClear;

  const BatchBar({
    super.key,
    required this.selectedCount,
    required this.isRunning,
    required this.onClaimAll,
    required this.onRepairAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: AppTheme.batchBar,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Selected count
          Expanded(
            child: Text(
              '$selectedCount account${selectedCount == 1 ? '' : 's'} selected',
              style: const TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      AppTheme.batchBarText,
              ),
            ),
          ),

          if (isRunning) ...[
            const SizedBox(
              width:  16,
              height: 16,
              child:  CircularProgressIndicator(
                strokeWidth: 2,
                color:       AppTheme.batchBarText,
              ),
            ),
          ] else ...[
            _BatchAction(
              label:   'Claim all',
              onTap:   onClaimAll,
            ),
            const SizedBox(width: 8),
            _BatchAction(
              label:   'Repair all',
              onTap:   onRepairAll,
            ),
          ],

          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              size:  18,
              color: AppTheme.batchBarText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchAction extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;

  const _BatchAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.w600,
            color:      AppTheme.batchBarText,
          ),
        ),
      ),
    );
  }
}
