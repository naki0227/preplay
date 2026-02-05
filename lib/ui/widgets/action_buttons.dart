import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PreplayController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary: Play
        SizedBox(
          width: double.infinity,
          // Removed fixed height, added padding
          child: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 16), // Dynamic height
            borderRadius: BorderRadius.circular(12),
            onPressed: () {
              // TODO: Implement Play state or logic
            },
            child: const Text('やる', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        
        // Secondary: Next
        SizedBox(
          width: double.infinity,
          // Removed fixed height
          child: CupertinoButton(
            color: CupertinoColors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.lightImpact(); // "Lightness"
              controller.next();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.separator),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                '次',
                style: TextStyle(
                  color: AppColors.label,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tertiary: Close
        CupertinoButton(
          onPressed: () {
             controller.dismiss(); // Resets to ambient state
          },
          child: const Text(
            '閉じる',
            style: TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
