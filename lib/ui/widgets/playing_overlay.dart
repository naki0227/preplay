import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class PlayingOverlay extends StatelessWidget {
  const PlayingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final game = controller.currentGame;
    final topic = controller.currentTopic;

    if (game == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.background, // Fill screen
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.clear, color: CupertinoColors.secondaryLabel),
                  onPressed: () => controller.stopGame(),
                ),
                Text(
                  game.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label,
                  ),
                ),
                const SizedBox(width: 44), // Spacer for balance
              ],
            ),
            
            const Spacer(),
            
            // Rules Display (Compact)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                game.rules,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.label,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Topic Display
            if (topic != null) ...[
              const Text(
                'お題',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              
              // Topic + Reroll Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 44), // Balancer
                  Expanded(
                    child: Text(
                      topic,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label,
                        height: 1.2,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      controller.rerollTopic();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.refresh, size: 20, color: AppColors.tintColor),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Let\'s Start!',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label,
                ),
              ),
            ],

            const Spacer(),
            
            // "Next Topic" if available? (Future enhancement)
            // For now just "Done"
            
            // Add Topic Button
            CupertinoButton(
              child: const Text('お題を追加', style: TextStyle(color: AppColors.tintColor)),
              onPressed: () => _showAddTopicDialog(context),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(12),
                child: const Text('終わり', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.stopGame();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddTopicDialog(BuildContext context) {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('お題を追加'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: '新しいお題を入力...',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('追加'),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<PreplayController>().addTopic(controller.text);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
